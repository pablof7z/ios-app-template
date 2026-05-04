import SwiftUI

// MARK: - GlassSurface modifier

// Liquid Glass surface — iOS 26 native .glassEffect() with blur, reflection,
// and light interaction. The tinted overload keys color to semantic state.

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

    func glassSurface(cornerRadius: CGFloat = 16, tint: Color, interactive: Bool = false) -> some View {
        self.glassEffect(
            interactive ? .regular.tint(tint).interactive() : .regular.tint(tint),
            in: .rect(cornerRadius: cornerRadius)
        )
    }
}

// MARK: - GlassCard container view

/// Padded glass card that wraps any content in a Liquid Glass surface.
/// For multiple sibling cards wrap them in GlassEffectContainer.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = AppTheme.Corner.lg
    var padding: CGFloat = AppTheme.Spacing.md
    var interactive: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .glassSurface(cornerRadius: cornerRadius, interactive: interactive)
    }
}

// MARK: - Prominent glass card extension

extension View {
    /// Glass surface with a shadow — for floating cards that need extra lift.
    func glassCard(cornerRadius: CGFloat = AppTheme.Corner.lg) -> some View {
        self
            .glassSurface(cornerRadius: cornerRadius)
            .appShadow(AppTheme.Shadow.card)
    }
}
