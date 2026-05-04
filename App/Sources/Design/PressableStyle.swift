import SwiftUI

struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func pressable(scale: CGFloat = 0.97) -> some View {
        self.buttonStyle(PressableStyle(scale: scale))
    }
}
