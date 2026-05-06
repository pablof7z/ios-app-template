import SwiftUI

// MARK: - Shared constants

private enum OnboardingLayout {
    static let pageIconSize: CGFloat = 60
    static let pageIconPadding: CGFloat = 28
    static let pageIconStroke: CGFloat = 0.3
    static let fieldVerticalPadding: CGFloat = 14
    /// Corner radius for the welcome sparkle medallion and its glass overlay.
    static let medallionCornerRadius: CGFloat = 36
}

// MARK: - Welcome

struct OnboardingWelcomePage: View {
    @State private var sparkleTrigger: Int = 0

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()
            sparkleMedallion
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("iOS App Template")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Your intelligent personal agent")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            Text("Liquid glass, AI agents, Nostr identity, and shake-to-feedback — all wired up and ready.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.md)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
    }

    private var sparkleMedallion: some View {
        ZStack {
            RoundedRectangle(cornerRadius: OnboardingLayout.medallionCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 148, height: 148)
                .glassEffect(.regular, in: .rect(cornerRadius: OnboardingLayout.medallionCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: OnboardingLayout.medallionCornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                )
                .appShadow(AppTheme.Shadow.lifted)

            Image(systemName: "sparkles")
                .font(.system(size: 76, weight: .semibold))
                .foregroundStyle(AppTheme.Gradients.onboardingSparkle)
                .symbolEffect(.bounce, options: .repeat(3), value: sparkleTrigger)
                .shadow(color: .white.opacity(0.6), radius: 12, x: 0, y: 0)
        }
        .onAppear {
            sparkleTrigger += 1
        }
    }
}

// MARK: - AI Setup

struct OnboardingAISetupPage: View {
    @Binding var apiKey: String
    var errorMessage: String?
    var isSaving: Bool
    var isConnectingBYOK: Bool
    var onConnectBYOK: () -> Void

    @State private var revealKey: Bool = false
    @State private var showManualEntry: Bool = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()
            pageIcon
            pageHeader
            actionArea
            Spacer()
        }
    }

    private var pageIcon: some View {
        Image(systemName: "key.viewfinder")
            .font(.system(size: OnboardingLayout.pageIconSize, weight: .semibold))
            .foregroundStyle(.white)
            .symbolEffect(.pulse, options: .repeating)
            .padding(OnboardingLayout.pageIconPadding)
            .glassEffect(.regular, in: .circle)
            .overlay(Circle().strokeBorder(.white.opacity(OnboardingLayout.pageIconStroke), lineWidth: 1))
    }

    private var pageHeader: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text("Connect your AI")
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(.white)

            Text("Connect OpenRouter to power your agent. Skip and add it later in Settings.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.md)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionArea: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            byokButton
            manualEntryToggle
            if showManualEntry { manualEntryField }
            if let errorMessage {
                Text(errorMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Tint.errorOnDark)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .animation(AppTheme.Animation.springFast, value: showManualEntry)
        .animation(AppTheme.Animation.springFast, value: errorMessage)
    }

    private var byokButton: some View {
        Button {
            onConnectBYOK()
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                if isConnectingBYOK {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "key.viewfinder")
                }
                Text(isConnectingBYOK ? "Connecting…" : "Connect with BYOK")
                    .font(AppTheme.Typography.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 28)
            .padding(.vertical, 8)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(.white)
        .foregroundStyle(.black)
        .disabled(isSaving)
    }

    private var manualEntryToggle: some View {
        Button {
            withAnimation(AppTheme.Animation.springFast) { showManualEntry.toggle() }
        } label: {
            Text(showManualEntry ? "Hide manual entry" : "Enter key manually")
                .font(AppTheme.Typography.callout)
                .foregroundStyle(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    private var manualEntryField: some View {
        GlassEffectContainer {
            VStack(spacing: AppTheme.Spacing.sm) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.white.opacity(0.7))
                    if revealKey {
                        TextField("sk-or-v1-…", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                    } else {
                        SecureField("sk-or-v1-…", text: $apiKey)
                            .foregroundStyle(.white)
                    }
                    Button {
                        revealKey.toggle()
                    } label: {
                        Image(systemName: revealKey ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .accessibilityLabel(revealKey ? "Hide API key" : "Show API key")
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, OnboardingLayout.fieldVerticalPadding)
                .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Corner.lg, style: .continuous)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                )

                Text("Stored securely in Keychain.")
                    .font(AppTheme.Typography.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppTheme.Spacing.sm)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Identity

struct OnboardingIdentityPage: View {
    @Binding var agentName: String
    @Binding var profilePicture: String

    private enum Layout {
        static let avatarSize: CGFloat = 90
        static let avatarIconSize: CGFloat = 36
        static let avatarFontSize: CGFloat = 32
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            avatarPreview

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Name your agent")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(.white)

                Text("Give your agent a name and a face. Both are optional and can change later.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GlassEffectContainer {
                VStack(spacing: AppTheme.Spacing.sm) {
                    fieldRow(icon: "person.fill", placeholder: "Agent name", text: $agentName)
                    fieldRow(icon: "photo.fill", placeholder: "Profile picture URL (optional)", text: $profilePicture, keyboard: .URL)
                }
            }

            Spacer()
        }
        .animation(AppTheme.Animation.springFast, value: validPictureURL)
        .animation(AppTheme.Animation.springFast, value: nameInitial)
    }

    // MARK: - Avatar Preview

    private var validPictureURL: URL? {
        let trimmed = profilePicture.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }

    private var nameInitial: String {
        agentName.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? ""
    }

    @ViewBuilder
    private var avatarPreview: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: Layout.avatarSize, height: Layout.avatarSize)
                .glassEffect(.regular, in: .circle)
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))

            if let url = validPictureURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        initialsOrPlaceholder
                    default:
                        ProgressView().tint(.white)
                    }
                }
                .frame(width: Layout.avatarSize, height: Layout.avatarSize)
                .clipShape(Circle())
            } else {
                initialsOrPlaceholder
            }
        }
        .appShadow(AppTheme.Shadow.lifted)
        .accessibilityLabel(validPictureURL != nil ? "Profile picture preview" : "Default profile placeholder")
    }

    @ViewBuilder
    private var initialsOrPlaceholder: some View {
        if nameInitial.isEmpty {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: Layout.avatarIconSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        } else {
            Text(nameInitial.uppercased())
                .font(.system(size: Layout.avatarFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Field

    private func fieldRow(icon: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 22)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(keyboard == .URL ? .never : .words)
                .autocorrectionDisabled(keyboard == .URL)
                .keyboardType(keyboard)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, OnboardingLayout.fieldVerticalPadding)
        .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Corner.lg, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Ready

struct OnboardingReadyPage: View {
    @State private var bounceTrigger: Int = 0

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()
            checkmarkMedallion
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("You're all set")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(.white)

                Text("Your agent is ready. Tap below to enter the app and start exploring.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Spacer()
        }
    }

    private var checkmarkMedallion: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: 180, height: 180)
                .glassEffect(.regular, in: .circle)
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .appShadow(AppTheme.Shadow.lifted)

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 100, weight: .bold))
                .foregroundStyle(AppTheme.Gradients.onboardingSuccess)
                .symbolEffect(.bounce, options: .repeat(3), value: bounceTrigger)
                .shadow(color: .white.opacity(0.5), radius: 12, x: 0, y: 0)
        }
        .onAppear {
            bounceTrigger += 1
        }
    }
}
