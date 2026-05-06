import SwiftUI

// MARK: - FriendAvatar

struct FriendAvatar: View {
    let friend: Friend
    var size: CGFloat = Layout.defaultSize

    // MARK: - Layout constants

    private enum Layout {
        /// Default avatar diameter when no explicit size is provided.
        static let defaultSize: CGFloat = 40
        /// Ratio of font size to avatar diameter — keeps the initial visually centered.
        static let fontSizeRatio: CGFloat = 0.38
        /// Opacity of the gradient end-stop colour (less saturated than the start).
        static let gradientEndOpacity: Double = 0.6
        /// Ordered palette for deterministic avatar colour derivation from a hash.
        static let palette: [Color] = [.blue, .purple, .pink, .orange, .green, .teal, .indigo]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarGradient)
                .frame(width: size, height: size)

            Text(String(friend.displayName.prefix(1)).uppercased())
                .font(.system(size: size * Layout.fontSizeRatio, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .accessibilityLabel(friend.displayName)
        .accessibilityAddTraits(.isImage)
    }

    private var avatarBaseColor: Color {
        let hash = abs(friend.identifier.hashValue)
        return Layout.palette[hash % Layout.palette.count]
    }

    private var avatarGradient: LinearGradient {
        LinearGradient(
            colors: [avatarBaseColor, avatarBaseColor.opacity(Layout.gradientEndOpacity)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
