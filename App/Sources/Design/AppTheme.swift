import SwiftUI

enum AppTheme {

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Corner radius

    enum Corner {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: - Animation presets

    enum Animation {
        static let spring = SwiftUI.Animation.spring(duration: 0.35, bounce: 0.15)
        static let springFast = SwiftUI.Animation.spring(duration: 0.22, bounce: 0.12)
        static let springBouncy = SwiftUI.Animation.spring(duration: 0.45, bounce: 0.3)
        static let easeOut = SwiftUI.Animation.easeOut(duration: 0.25)
        static let easeIn = SwiftUI.Animation.easeIn(duration: 0.2)
    }

    // MARK: - Typography

    enum Typography {
        static let largeTitle = SwiftUI.Font.system(.largeTitle, design: .rounded, weight: .bold)
        static let title = SwiftUI.Font.system(.title2, design: .rounded, weight: .semibold)
        static let headline = SwiftUI.Font.system(.headline, design: .rounded, weight: .semibold)
        static let body = SwiftUI.Font.system(.body, design: .default)
        static let callout = SwiftUI.Font.system(.callout, design: .default)
        static let caption = SwiftUI.Font.system(.caption, design: .default).weight(.medium)
        static let caption2 = SwiftUI.Font.system(.caption2, design: .default)
        static let mono = SwiftUI.Font.system(.caption2, design: .monospaced)
    }

    // MARK: - Gradients

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
    }

    // MARK: - Shadows

    enum Shadow {
        struct Style {
            var color: SwiftUI.Color
            var radius: CGFloat
            var x: CGFloat
            var y: CGFloat
        }
        static let subtle = Style(color: .black.opacity(0.07), radius: 4, x: 0, y: 2)
        static let card = Style(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
        static let lifted = Style(color: .black.opacity(0.16), radius: 20, x: 0, y: 8)
    }
}

// MARK: - View extensions

extension View {
    func appShadow(_ style: AppTheme.Shadow.Style) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
