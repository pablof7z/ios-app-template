import CoreSpotlight
import SwiftUI

/// The tabs available at the root navigation level.
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

/// The root view of the app. Hosts the main tab bar, the feedback shake gesture,
/// onboarding gate, and deep-link routing.
struct RootView: View {
    @Environment(AppStateStore.self) private var store
    @State private var selectedTab: RootTab = .home
    @State private var feedbackWorkflow = FeedbackWorkflow()
    @State private var showFeedback = false
    @State private var lastShakeTime: Date = .distantPast
    @State private var pendingNewItemTitle: String?
    /// Item ID received from a Handoff or Spotlight continuation; HomeView opens the edit sheet.
    @State private var pendingEditItemID: UUID?

    var body: some View {
        tabBar
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
            .fullScreenCover(
                isPresented: Binding(
                    get: { !store.state.settings.hasCompletedOnboarding },
                    set: { _ in }
                )
            ) {
                OnboardingView()
            }
            .onOpenURL { handleDeepLink($0) }
            .onReceive(
                NotificationCenter.default.publisher(for: AppDelegate.shortcutURLNotification)
            ) { note in
                if let url = note.object as? URL { handleDeepLink(url) }
            }
            .onContinueUserActivity(HandoffActivityType.editItem, perform: handleHandoff)
            .onContinueUserActivity(CSSearchableItemActionType, perform: handleSpotlight)
    }

    private var tabBar: some View {
        TabView(selection: $selectedTab) {
            ForEach(RootTab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem { Label(tab.rawValue, systemImage: tab.icon) }
                    .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: RootTab) -> some View {
        switch tab {
        case .home:
            NavigationStack {
                HomeView(
                    pendingNewItemTitle: $pendingNewItemTitle,
                    pendingEditItemID: $pendingEditItemID
                )
            }
        case .settings:
            NavigationStack { SettingsView() }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard let link = DeepLinkHandler.resolve(url) else { return }
        switch link {
        case .settings:
            selectedTab = .settings
        case .feedback:
            showFeedback = true
        case .newItem(let title):
            selectedTab = .home
            pendingNewItemTitle = title
        case .overdue:
            selectedTab = .home
        }
    }

    /// Routes a Spotlight continuation activity to the correct in-app screen.
    ///
    /// - Items:    switches to Home and opens the item's edit sheet via `pendingEditItemID`.
    /// - Notes:    switches to Home so the user can search for the note.
    /// - Memories: switches to Settings; the agent memories live under Agent → Memories.
    private func handleSpotlight(_ activity: NSUserActivity) {
        guard let link = SpotlightIndexer.deepLink(from: activity) else { return }
        switch link {
        case .item(let id):
            selectedTab = .home
            pendingEditItemID = id
        case .note:
            selectedTab = .home
        case .memory:
            selectedTab = .settings
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

    /// Handles a Handoff continuation for ``HandoffActivityType/editItem``.
    /// Switches to the Home tab and sets `pendingEditItemID` so `HomeView`
    /// can open the edit sheet for the matching item.
    ///
    /// If the item doesn't exist on this device (e.g. iCloud hasn't synced yet),
    /// `HomeView` will fall through silently — no crash, just no sheet.
    private func handleHandoff(_ activity: NSUserActivity) {
        guard let idString = activity.userInfo?[HandoffUserInfoKey.itemID] as? String,
              let itemID = UUID(uuidString: idString)
        else { return }
        selectedTab = .home
        pendingEditItemID = itemID
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
