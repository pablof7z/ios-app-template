import SwiftUI

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
