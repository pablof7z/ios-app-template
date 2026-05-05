import SwiftUI

// MARK: - Welcome

struct OnboardingWelcomePage: View {
    @State private var sparkleTrigger: Int = 0

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
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
                    .glassEffect(.regular, in: .rect(cornerRadius: 36))
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    )
                    .appShadow(AppTheme.Shadow.lifted)

                Image(systemName: "sparkles")
                    .font(.system(size: 76, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(red: 0.85, green: 0.92, blue: 1.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .symbolEffect(.bounce, options: .repeat(3), value: sparkleTrigger)
                    .shadow(color: .white.opacity(0.6), radius: 12, x: 0, y: 0)
            }
            .onAppear {
                sparkleTrigger += 1
            }

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
}

// MARK: - AI Setup

struct OnboardingAISetupPage: View {
    @Binding var apiKey: String
    var errorMessage: String?
    var isSaving: Bool

    @State private var revealKey: Bool = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            Image(systemName: "key.viewfinder")
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, options: .repeating)
                .padding(28)
                .glassEffect(.regular, in: .circle)
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Connect your AI")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(.white)

                Text("Paste an OpenRouter API key to power your agent. You can also skip and add it later in Settings.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, 14)
                    .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Corner.lg, style: .continuous)
                            .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Color(red: 1.0, green: 0.7, blue: 0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .transition(.opacity)
                    }

                    Text("Stored securely in Keychain. Never leaves your device unencrypted.")
                        .font(AppTheme.Typography.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                }
            }
            .animation(AppTheme.Animation.springFast, value: errorMessage)

            Spacer()
        }
    }
}

// MARK: - Identity

struct OnboardingIdentityPage: View {
    @Binding var agentName: String
    @Binding var profilePicture: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, options: .repeat(2))
                .padding(28)
                .glassEffect(.regular, in: .circle)
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))

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
    }

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
        .padding(.vertical, 14)
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

            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 180, height: 180)
                    .glassEffect(.regular, in: .circle)
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                    .appShadow(AppTheme.Shadow.lifted)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 100, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(red: 0.7, green: 1.0, blue: 0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .symbolEffect(.bounce, options: .repeat(3), value: bounceTrigger)
                    .shadow(color: .white.opacity(0.5), radius: 12, x: 0, y: 0)
            }
            .onAppear {
                bounceTrigger += 1
            }

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
}
