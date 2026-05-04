import SwiftUI

// Liquid Glass surface modifier — uses iOS 26 native .glassEffect() for blur,
// reflection, and light interaction. Falls back to nothing for pre-26 (not targeted).
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 16
    var isInteractive: Bool = false

    func body(content: Content) -> some View {
        content
            .glassEffect(
                isInteractive ? .regular.interactive() : .regular,
                in: .rect(cornerRadius: cornerRadius)
            )
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = 16, interactive: Bool = false) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, isInteractive: interactive))
    }

    // Tinted glass — useful for status banners (blue = running, green = done, etc.)
    func glassSurface(cornerRadius: CGFloat = 16, tint: Color, interactive: Bool = false) -> some View {
        self.glassEffect(
            interactive
                ? .regular.tint(tint).interactive()
                : .regular.tint(tint),
            in: .rect(cornerRadius: cornerRadius)
        )
    }
}
