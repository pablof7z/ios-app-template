import SwiftUI

// MARK: - PressableStyle (subtle scale)

struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(AppTheme.Animation.springFast, value: configuration.isPressed)
    }
}

// MARK: - BouncyPressableStyle (spring overshoot on release)

struct BouncyPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.91 : 1.0)
            .animation(AppTheme.Animation.springBouncy, value: configuration.isPressed)
    }
}

// MARK: - Extensions

extension View {
    func pressable(scale: CGFloat = 0.97) -> some View {
        self.buttonStyle(PressableStyle(scale: scale))
    }

    func bouncyPress() -> some View {
        self.buttonStyle(BouncyPressableStyle())
    }
}
