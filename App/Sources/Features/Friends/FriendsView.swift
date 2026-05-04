import SwiftUI

struct FriendsView: View {
    @Environment(AppStateStore.self) private var store
    @State private var showAddFriend = false
    @State private var selectedFriend: Friend?

    var body: some View {
        List {
            if store.state.friends.isEmpty {
                ContentUnavailableView(
                    "No friends yet",
                    systemImage: "person.2",
                    description: Text("Add friends to share and collaborate on tasks.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.state.friends) { friend in
                    Button { selectedFriend = friend } label: {
                        FriendRow(friend: friend)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddFriend = true
                } label: {
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
}

// MARK: - FriendRow

struct FriendRow: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            FriendAvatar(friend: friend, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.body)

                if let about = friend.about {
                    Text(about)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(friend.identifier)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - FriendAvatar

struct FriendAvatar: View {
    let friend: Friend
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(avatarColor)
            .frame(width: size, height: size)
            .overlay(
                Text(String(friend.displayName.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }

    private var avatarColor: Color {
        // Deterministic color from identifier string
        let hash = abs(friend.identifier.hashValue)
        let colors: [Color] = [.blue, .purple, .pink, .orange, .green, .teal, .indigo]
        return colors[hash % colors.count]
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
                    Text("The identifier uniquely identifies your friend. It can be a Nostr pubkey, username, email, or any unique string your app uses.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
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
