import SwiftUI

struct FriendsView: View {
    @Environment(AppStateStore.self) private var store
    @State private var showAddFriend = false
    @State private var selectedFriend: Friend?
    @State private var searchText = ""

    private var filteredFriends: [Friend] {
        let all = store.state.friends
        if searchText.isEmpty { return all }
        return all.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.identifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func itemCount(for friend: Friend) -> Int {
        store.state.items.filter { !$0.deleted && $0.requestedByFriendID == friend.id }.count
    }

    var body: some View {
        List {
            if store.state.friends.isEmpty {
                emptyState
            } else {
                ForEach(filteredFriends) { friend in
                    Button { selectedFriend = friend } label: {
                        FriendRow(friend: friend, itemCount: itemCount(for: friend))
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            store.removeFriend(friend.id)
                        } label: {
                            Label("Remove", systemImage: "person.slash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Friends")
        .navigationSubtitle(store.state.friends.isEmpty ? "" : subtitle)
        .searchable(text: $searchText, prompt: "Search friends")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddFriend = true } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet(isPresented: $showAddFriend)
        }
        .sheet(item: $selectedFriend) { friend in
            FriendDetailView(friend: friend)
        }
    }

    private var subtitle: String {
        let totalTasks = store.state.friends.reduce(0) { $0 + itemCount(for: $1) }
        let f = store.state.friends.count
        let fStr = "\(f) \(f == 1 ? "friend" : "friends")"
        if totalTasks == 0 { return fStr }
        return "\(fStr) · \(totalTasks) \(totalTasks == 1 ? "task" : "tasks")"
    }

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView(
            "No friends yet",
            systemImage: "person.2.circle",
            description: Text("Add friends to collaborate on tasks.")
        )
        .listRowBackground(Color.clear)
    }
}

// MARK: - FriendRow

struct FriendRow: View {
    let friend: Friend
    var itemCount: Int = 0

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            FriendAvatar(friend: friend, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(AppTheme.Typography.body)

                if let about = friend.about {
                    Text(about)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(friend.identifier)
                        .font(AppTheme.Typography.mono)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if itemCount > 0 {
                StatBadge.tasks(itemCount)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }
}

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

// MARK: - AddFriendSheet

private struct AddFriendSheet: View {
    @Environment(AppStateStore.self) private var store
    @Binding var isPresented: Bool
    @State private var displayName = ""
    @State private var identifier = ""
    @FocusState private var focusedField: Field?

    enum Field { case name, identifier }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display Name", text: $displayName)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .identifier }

                    TextField("Identifier (username, pubkey, etc.)", text: $identifier)
                        .focused($focusedField, equals: .identifier)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.callout.monospaced())
                }

                Section {
                    Text("The identifier uniquely identifies your friend — a Nostr pubkey, username, email, or any unique string your app uses.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .fontWeight(.semibold)
                        .disabled(displayName.isEmpty || identifier.isEmpty)
                }
            }
            .onAppear { focusedField = .name }
        }
        .presentationDetents([.medium])
    }

    private func add() {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !id.isEmpty else { return }
        _ = store.addFriend(displayName: name, identifier: id)
        Haptics.success()
        isPresented = false
    }
}
