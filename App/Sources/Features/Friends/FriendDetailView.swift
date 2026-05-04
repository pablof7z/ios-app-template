import SwiftUI

struct FriendDetailView: View {
    @Environment(AppStateStore.self) private var store
    let friend: Friend
    @State private var showRenameAlert = false
    @State private var newName = ""
    @Environment(\.dismiss) private var dismiss

    private var currentFriend: Friend {
        store.state.friends.first { $0.id == friend.id } ?? friend
    }

    private var friendItems: [Item] {
        store.state.items.filter { !$0.deleted && $0.requestedByFriendID == friend.id }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: AppTheme.Spacing.md) {
                        FriendAvatar(friend: currentFriend, size: 56)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentFriend.displayName)
                                .font(.title3.bold())

                            Text(currentFriend.identifier)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospaced()
                                .lineLimit(2)

                            if let about = currentFriend.about {
                                Text(about)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !friendItems.isEmpty {
                    Section("Tasks from \(currentFriend.displayName)") {
                        ForEach(friendItems) { item in
                            HStack {
                                Image(systemName: item.status == .done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.status == .done ? .green : .secondary)
                                Text(item.title)
                                    .strikethrough(item.status == .done)
                                    .foregroundStyle(item.status == .done ? .secondary : .primary)
                            }
                            .font(.callout)
                        }
                    }
                }

                Section {
                    Button("Rename") {
                        newName = currentFriend.displayName
                        showRenameAlert = true
                    }
                }

                Section {
                    Button("Remove Friend", role: .destructive) {
                        store.removeFriend(friend.id)
                        dismiss()
                    }
                }
            }
            .navigationTitle(currentFriend.displayName)
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Rename Friend", isPresented: $showRenameAlert) {
            TextField("Display Name", text: $newName)
            Button("Save") {
                let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                store.updateFriendDisplayName(friend.id, newName: trimmed)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
