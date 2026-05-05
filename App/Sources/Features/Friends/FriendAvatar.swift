import SwiftUI

// MARK: - FriendAvatar

struct FriendAvatar: View {
    let friend: Friend
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarGradient)
                .frame(width: size, height: size)

            Text(String(friend.displayName.prefix(1)).uppercased())
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .accessibilityLabel(friend.displayName)
        .accessibilityAddTraits(.isImage)
    }

    private var avatarBaseColor: Color {
        let hash = abs(friend.identifier.hashValue)
        let colors: [Color] = [.blue, .purple, .pink, .orange, .green, .teal, .indigo]
        return colors[hash % colors.count]
    }

    private var avatarGradient: LinearGradient {
        LinearGradient(
            colors: [avatarBaseColor, avatarBaseColor.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
