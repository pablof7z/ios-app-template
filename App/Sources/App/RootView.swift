import CoreSpotlight
import SwiftUI

enum RootTab: String, CaseIterable {
    case home = "Home"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .settings: "gear"
        }
    }
}

struct RootView: View {
    @Environment(AppStateStore.self) private var store
    @State private var selectedTab: RootTab = .home
    @State private var feedbackWorkflow = FeedbackWorkflow()
    @State private var showFeedback = false
    @State private var lastShakeTime: Date = .distantPast

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(RootTab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem { Label(tab.rawValue, systemImage: tab.icon) }
                    .tag(tab)
            }
        }
        .onShake { handleShake() }
        .sheet(isPresented: $showFeedback) {
            FeedbackView(workflow: feedbackWorkflow)
        }
        .fullScreenCover(
            isPresented: .init(
                get: { feedbackWorkflow.isAnnotationVisible },
                set: { if !$0 { feedbackWorkflow.phase = .composing } }
            )
        ) {
            ScreenshotAnnotationView(workflow: feedbackWorkflow)
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            handleSpotlightContinuation(activity)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { !store.state.settings.hasCompletedOnboarding },
                set: { _ in }
            )
        ) {
            OnboardingView()
        }
    }

    @ViewBuilder
    private func tabContent(for tab: RootTab) -> some View {
        switch tab {
        case .home:
            NavigationStack { HomeView() }
        case .settings:
            NavigationStack { SettingsView() }
        }
    }

    private func handleShake() {
        let now = Date()
        guard now.timeIntervalSince(lastShakeTime) > 1.0 else { return }
        lastShakeTime = now

        if feedbackWorkflow.phase == .awaitingScreenshot {
            feedbackWorkflow.screenshot = captureScreenshot()
            feedbackWorkflow.phase = .annotating
        } else {
            Haptics.medium()
            feedbackWorkflow.draft = ""
            feedbackWorkflow.screenshot = nil
            feedbackWorkflow.annotatedImage = nil
            feedbackWorkflow.phase = .composing
            showFeedback = true
        }
    }

    private func handleSpotlightContinuation(_ activity: NSUserActivity) {
        guard let link = SpotlightIndexer.deepLink(from: activity) else { return }
        // Both items and notes live on Home today; if the template grows a
        // dedicated Notes tab, route by `link` here.
        selectedTab = .home
        store.pendingSpotlightLink = link
        Haptics.selection()
    }

    private func captureScreenshot() -> UIImage? {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first
        else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { ctx in window.layer.render(in: ctx.cgContext) }
    }
}
