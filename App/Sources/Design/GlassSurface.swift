import SwiftUI

struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius))
    }
}
