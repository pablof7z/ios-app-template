import SwiftUI

/// Central design-token namespace for the app.
///
/// Use nested enums (`Spacing`, `Corner`, `Typography`, etc.) to access
/// individual tokens. Never hardcode raw values where a token exists.
enum AppTheme {

    // MARK: - Spacing

    /// Layout spacing scale — use these for padding and stack gaps.
    enum Spacing {
        /// 4 pt — micro gap between tightly related elements.
        static let xs: CGFloat = 4
        /// 8 pt — small inset or gap.
        static let sm: CGFloat = 8
        /// 16 pt — standard content padding.
        static let md: CGFloat = 16
        /// 24 pt — section-level spacing.
        static let lg: CGFloat = 24
        /// 32 pt — large section gap or hero padding.
        static let xl: CGFloat = 32
    }

    // MARK: - Corner radius

    /// Corner-radius scale for cards, buttons, and surfaces.
    enum Corner {
        /// 8 pt — small buttons and chips.
        static let sm: CGFloat = 8
        /// 12 pt — compact cards and input fields.
        static let md: CGFloat = 12
        /// 16 pt — standard cards and glass surfaces.
        static let lg: CGFloat = 16
        /// 24 pt — large hero cards and bottom sheets.
        static let xl: CGFloat = 24
    }

    // MARK: - Animation presets

    /// Pre-tuned SwiftUI animation curves for consistent motion.
    enum Animation {
        /// Default spring — most transitions and reveals.
        static let spring = SwiftUI.Animation.spring(duration: 0.35, bounce: 0.15)
        /// Fast spring — quick feedback interactions.
        static let springFast = SwiftUI.Animation.spring(duration: 0.22, bounce: 0.12)
        /// Bouncy spring — playful entrances.
        static let springBouncy = SwiftUI.Animation.spring(duration: 0.45, bounce: 0.3)
        /// Ease-out — elements sliding into a resting position.
        static let easeOut = SwiftUI.Animation.easeOut(duration: 0.25)
        /// Ease-in — elements leaving the screen.
        static let easeIn = SwiftUI.Animation.easeIn(duration: 0.2)
        /// Ease-in-out — looping UI elements such as typing-indicator dots.
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: 0.3)
    }

    // MARK: - Typography

    /// App-wide font definitions using Dynamic Type text styles.
    ///
    /// Rounded design is used for display and heading levels;
    /// body and smaller sizes use the default design for readability.
    enum Typography {
        /// Rounded bold — screen titles and hero text.
        static let largeTitle = SwiftUI.Font.system(.largeTitle, design: .rounded, weight: .bold)
        /// Rounded semibold — section headers.
        static let title = SwiftUI.Font.system(.title2, design: .rounded, weight: .semibold)
        /// Rounded semibold — list headers and prominent labels.
        static let headline = SwiftUI.Font.system(.headline, design: .rounded, weight: .semibold)
        /// Default body weight — primary reading text.
        static let body = SwiftUI.Font.system(.body, design: .default)
        /// Default callout — supporting copy below headlines.
        static let callout = SwiftUI.Font.system(.callout, design: .default)
        /// Medium-weight caption — metadata and secondary labels.
        static let caption = SwiftUI.Font.system(.caption, design: .default).weight(.medium)
        /// Default caption2 — smallest readable label.
        static let caption2 = SwiftUI.Font.system(.caption2, design: .default)
        /// Monospaced caption2 — keys, tokens, and code snippets.
        static let mono = SwiftUI.Font.system(.caption2, design: .monospaced)
    }

    // MARK: - Brand colors

    /// Named brand-color tokens for third-party integrations.
    ///
    /// Add a token here whenever a partner color appears in more than one file.
    enum Brand {
        /// ElevenLabs signature teal — used across all ElevenLabs UI surfaces.
        static let elevenLabsTint = SwiftUI.Color(red: 0, green: 0.78, blue: 0.62)
    }

    // MARK: - Layout sizes

    /// Fixed-size tokens for icons, avatars, and circular buttons.
    ///
    /// Use these instead of hardcoding `frame(width:height:)` values.
    enum Layout {
        /// 36 pt — small circular avatar or icon-only button tap target.
        static let iconSm: CGFloat = 36
        /// 64 pt — medium profile avatar.
        static let iconLg: CGFloat = 64
    }

    // MARK: - Gradients

    /// Shared gradient definitions for brand surfaces.
    enum Gradients {
        /// Brand gradient used by the agent send button and user chat bubbles.
        static let agentAccent = LinearGradient(
            colors: [
                Color(red: 0.36, green: 0.20, blue: 0.84),
                Color(red: 0.14, green: 0.45, blue: 0.92),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Deep-navy-to-teal nebula used as the full-screen onboarding background.
        static let onboardingNebula = LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.04, blue: 0.20),
                Color(red: 0.18, green: 0.10, blue: 0.42),
                Color(red: 0.10, green: 0.32, blue: 0.66),
                Color(red: 0.04, green: 0.55, blue: 0.74)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// White-to-ice-blue shimmer for the welcome sparkle icon.
        static let onboardingSparkle = LinearGradient(
            colors: [.white, Color(red: 0.85, green: 0.92, blue: 1.0)],
            startPoint: .top,
            endPoint: .bottom
        )

        /// White-to-mint shimmer for the completion checkmark icon.
        static let onboardingSuccess = LinearGradient(
            colors: [.white, Color(red: 0.7, green: 1.0, blue: 0.85)],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Subtle green-teal tint used as the item compose/edit sheet background.
        static let itemSheetBackground = LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.green.opacity(0.05),
                Color.teal.opacity(0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Subtle indigo-blue tint used as the agent chat view background.
        static let agentChatBackground = LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.indigo.opacity(0.05),
                Color.blue.opacity(0.04),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Semantic tints

    /// One-off semantic color tokens that don't belong to a third-party brand.
    enum Tint {
        /// Soft red used for inline error messages on dark backgrounds.
        static let errorOnDark = SwiftUI.Color(red: 1.0, green: 0.7, blue: 0.7)
        /// Soft lavender used for the AI-agent feature chip on the onboarding ready page.
        static let onboardingChipAI = SwiftUI.Color(red: 0.80, green: 0.70, blue: 1.0)
        /// Ice-blue used for the friends feature chip on the onboarding ready page.
        static let onboardingChipFriends = SwiftUI.Color(red: 0.60, green: 0.88, blue: 1.0)
        /// Mint-green used for the feedback feature chip on the onboarding ready page.
        static let onboardingChipFeedback = SwiftUI.Color(red: 0.70, green: 1.0, blue: 0.85)
    }

    // MARK: - Timing

    /// Duration constants for Task.sleep-based UI feedback and animation delays.
    ///
    /// Use these instead of hardcoding raw `.seconds()` / `.milliseconds()` values
    /// so all copy-feedback, completion-animation, and typing-indicator delays stay in sync.
    enum Timing {
        /// 1.5 s — standard "Copied!" chip display time across agent/identity views.
        static let copyFeedback: Duration = .seconds(1.5)
        /// 220 ms — row scale-out delay before removing a completed item.
        static let itemCompletionDelay: Duration = .milliseconds(220)
        /// 350 ms — typing-indicator dot phase cycle step.
        static let typingDotStep: Duration = .milliseconds(350)
        /// 600 ms — simulated publish latency for a new feedback thread.
        static let feedbackPublishDelay: Duration = .milliseconds(600)
        /// 300 ms — simulated reply latency for a feedback thread reply.
        static let feedbackReplyDelay: Duration = .milliseconds(300)
    }

    // MARK: - Shadows

    /// Drop-shadow presets for elevating surfaces above the background.
    enum Shadow {
        /// Parameters for a single drop-shadow layer.
        struct Style {
            var color: SwiftUI.Color
            var radius: CGFloat
            var x: CGFloat
            var y: CGFloat
        }
        /// Barely-there lift — use on inline cards and small chips.
        static let subtle = Style(color: .black.opacity(0.07), radius: 4, x: 0, y: 2)
        /// Moderate elevation — standard card shadow.
        static let card = Style(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
        /// High elevation — floating panels and modals.
        static let lifted = Style(color: .black.opacity(0.16), radius: 20, x: 0, y: 8)
    }
}

// MARK: - View extensions

extension View {
    func appShadow(_ style: AppTheme.Shadow.Style) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
