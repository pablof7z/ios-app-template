import SwiftUI

enum AgentFriendsConstants {
    /// Diameter of the avatar circle used in friend list rows and initials placeholders.
    static let avatarSize: CGFloat = 40
    /// Horizontal spacing between avatar and text in a friend row.
    static let rowSpacing: CGFloat = 12
    /// Vertical spacing between the display name and the identifier/about lines.
    static let labelSpacing: CGFloat = 2
    /// Minimum spacer width between the label block and the trailing date.
    static let trailingSpacerMin: CGFloat = 8
    /// Vertical padding applied to each friend row.
    static let rowVerticalPadding: CGFloat = 2
    /// Point size of the initial letter rendered inside the initials avatar.
    static let initialsSize: CGFloat = 16
    /// Padding applied to the instruction pill in the camera viewfinder overlay.
    static let pillHorizontalPadding: CGFloat = 16
    static let pillVerticalPadding: CGFloat = 8
    static let pillBottomPadding: CGFloat = 32
    /// Side length of the QR viewfinder guide frame.
    static let viewfinderSize: CGFloat = 200
    /// Stroke width of the viewfinder guide frame.
    static let viewfinderLineWidth: CGFloat = 2
    /// Opacity of the viewfinder guide frame border.
    static let viewfinderBorderOpacity: Double = 0.6
}

struct AgentFriendsView: View {
    @Environment(AppStateStore.self) private var store
    @State private var showAddFriend = false
    @State private var searchText = ""

    private var sortedFriends: [Friend] {
        store.state.friends.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private var filteredFriends: [Friend] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sortedFriends }
        return sortedFriends.filter {
            $0.displayName.localizedCaseInsensitiveContains(trimmed) ||
            $0.identifier.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        List {
            if store.state.friends.isEmpty {
                ContentUnavailableView {
                    Label("No friends yet", systemImage: "person.2")
                } description: {
                    Text("Add a friend by their Nostr public key (npub or hex).")
                } actions: {
                    Button("Add Friend") { showAddFriend = true }
                        .buttonStyle(.glassProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredFriends) { friend in
                    NavigationLink {
                        FriendDetailView(friend: friend)
                    } label: {
                        FriendListRow(friend: friend)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            store.removeFriend(friend.id)
                            Haptics.selection()
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search friends")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddFriend = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet()
        }
    }
}

// MARK: - FriendListRow

private struct FriendListRow: View {
    let friend: Friend

    var body: some View {
        HStack(alignment: .top, spacing: AgentFriendsConstants.rowSpacing) {
            avatar

            VStack(alignment: .leading, spacing: AgentFriendsConstants.labelSpacing) {
                Text(friend.displayName)
                    .font(AppTheme.Typography.headline)

                Text(friend.shortIdentifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                if let about = friend.about, !about.isEmpty {
                    Text(about)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: AgentFriendsConstants.trailingSpacerMin)

            Text(friend.addedAt.formatted(date: .abbreviated, time: .omitted))
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, AgentFriendsConstants.rowVerticalPadding)
    }

    @ViewBuilder
    private var avatar: some View {
        if let urlString = friend.avatarURL,
           let url = URL(string: urlString),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty, .failure:
                    initialsAvatar
                @unknown default:
                    initialsAvatar
                }
            }
            .frame(width: AgentFriendsConstants.avatarSize, height: AgentFriendsConstants.avatarSize)
            .clipShape(Circle())
        } else {
            initialsAvatar
        }
    }

    private var initialsAvatar: some View {
        let hue = Double(abs(friend.identifier.hashValue) % 360) / 360.0
        let base = Color(hue: hue, saturation: 0.65, brightness: 0.82)
        let dim = Color(hue: hue, saturation: 0.65, brightness: 0.65)
        return ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [base, dim],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text(String(friend.displayName.prefix(1)).uppercased())
                .font(.system(size: AgentFriendsConstants.initialsSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: AgentFriendsConstants.avatarSize, height: AgentFriendsConstants.avatarSize)
    }
}
