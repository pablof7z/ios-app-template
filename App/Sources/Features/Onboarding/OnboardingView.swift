import SwiftUI

struct OnboardingView: View {
    @Environment(AppStateStore.self) private var store

    @State private var pageIndex: Int = 0
    @State private var apiKeyDraft: String = ""
    @State private var apiKeyError: String?
    @State private var apiKeySaving: Bool = false
    @State private var agentNameDraft: String = ""
    @State private var profilePictureDraft: String = ""

    private let pageCount: Int = 4

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                pages
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Pages

    private var pages: some View {
        TabView(selection: $pageIndex) {
            OnboardingWelcomePage()
                .tag(0)
                .padding(.horizontal, AppTheme.Spacing.lg)

            OnboardingAISetupPage(
                apiKey: $apiKeyDraft,
                errorMessage: apiKeyError,
                isSaving: apiKeySaving
            )
            .tag(1)
            .padding(.horizontal, AppTheme.Spacing.lg)

            OnboardingIdentityPage(
                agentName: $agentNameDraft,
                profilePicture: $profilePictureDraft
            )
            .tag(2)
            .padding(.horizontal, AppTheme.Spacing.lg)

            OnboardingReadyPage()
                .tag(3)
                .padding(.horizontal, AppTheme.Spacing.lg)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .animation(AppTheme.Animation.spring, value: pageIndex)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            if pageIndex > 0 {
                Button {
                    Haptics.selection()
                    withAnimation(AppTheme.Animation.spring) { pageIndex -= 1 }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(AppTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if shouldShowSkip {
                Button {
                    Haptics.selection()
                    advanceOrFinish()
                } label: {
                    Text("Skip")
                        .font(AppTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.md)
        .frame(height: 60)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Button {
                Haptics.medium()
                primaryAction()
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(primaryButtonTitle)
                        .font(AppTheme.Typography.headline)
                    if pageIndex < pageCount - 1 {
                        Image(systemName: "arrow.right")
                            .font(.headline.weight(.semibold))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.headline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 28)
                .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.white)
            .foregroundStyle(.black)
            .disabled(apiKeySaving)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.sm)
    }

    // MARK: - Logic

    private var shouldShowSkip: Bool {
        pageIndex == 1 || pageIndex == 2
    }

    private var primaryButtonTitle: String {
        switch pageIndex {
        case 0: "Get Started"
        case 1: apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Continue" : "Save Key"
        case 2: agentNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Continue" : "Save"
        default: "Enter App"
        }
    }

    private func primaryAction() {
        switch pageIndex {
        case 1:
            handleAISetupContinue()
        case 2:
            handleIdentityContinue()
        case pageCount - 1:
            finishOnboarding()
        default:
            advanceOrFinish()
        }
    }

    private func advanceOrFinish() {
        if pageIndex < pageCount - 1 {
            withAnimation(AppTheme.Animation.spring) { pageIndex += 1 }
        } else {
            finishOnboarding()
        }
    }

    private func handleAISetupContinue() {
        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            apiKeyError = nil
            advanceOrFinish()
            return
        }
        apiKeySaving = true
        apiKeyError = nil
        do {
            try OpenRouterCredentialStore.saveAPIKey(trimmed)
            var s = store.state.settings
            s.markOpenRouterManual()
            store.updateSettings(s)
            apiKeyDraft = ""
            apiKeySaving = false
            Haptics.success()
            advanceOrFinish()
        } catch {
            apiKeySaving = false
            apiKeyError = "Could not save key. Tap Skip or try again."
            Haptics.error()
        }
    }

    private func handleIdentityContinue() {
        var s = store.state.settings
        let nameTrimmed = agentNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let pictureTrimmed = profilePictureDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nameTrimmed.isEmpty {
            s.nostrProfileName = nameTrimmed
        }
        if !pictureTrimmed.isEmpty {
            s.nostrProfilePicture = pictureTrimmed
        }
        store.updateSettings(s)
        Haptics.success()
        advanceOrFinish()
    }

    private func finishOnboarding() {
        var s = store.state.settings
        s.hasCompletedOnboarding = true
        store.updateSettings(s)
        Haptics.success()
    }

    // MARK: - Background

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.04, blue: 0.20),
                Color(red: 0.18, green: 0.10, blue: 0.42),
                Color(red: 0.10, green: 0.32, blue: 0.66),
                Color(red: 0.04, green: 0.55, blue: 0.74)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
