import SwiftUI

struct FriendDetailView: View {
    @Environment(AppStateStore.self) private var store
    let friend: Friend
    @State private var showRenameAlert = false
    @State private var newName = ""
    @State private var showCopiedFeedback = false
    @Environment(\.dismiss) private var dismiss
    @Namespace private var glassNS

    private var currentFriend: Friend {
        store.state.friends.first { $0.id == friend.id } ?? friend
    }

    private var friendItems: [Item] {
        store.state.items
            .filter { !$0.deleted && $0.requestedByFriendID == friend.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var friendNotes: [Note] {
        let itemIDs = Set(friendItems.map(\.id))
        return store.activeNotes.filter {
            if case .item(let id) = $0.target { return itemIDs.contains(id) }
            return false
        }
    }

    private var addedDateString: String {
        "Friends since " + currentFriend.addedAt.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        NavigationStack {
            List {
                // Glass profile header — clear listRowBackground so glass renders properly
                Section {
                    profileHeader
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if !friendItems.isEmpty {
                    Section("Tasks from \(currentFriend.displayName)") {
                        ForEach(friendItems) { item in
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: item.status == .done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.status == .done ? .green : .secondary)
                                    .contentTransition(.symbolEffect(.replace))
                                Text(item.title)
                                    .strikethrough(item.status == .done)
                                    .foregroundStyle(item.status == .done ? .secondary : .primary)
                            }
                            .font(AppTheme.Typography.callout)
                            .opacity(item.status == .done ? 0.55 : 1)
                        }
                    }
                }

                if !friendNotes.isEmpty {
                    Section("Notes") {
                        ForEach(friendNotes) { note in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.text)
                                    .font(AppTheme.Typography.callout)
                                    .lineLimit(3)
                                Text(note.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(.tertiary)
                            }
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
                        Haptics.medium()
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
                let t = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                store.updateFriendDisplayName(friend.id, newName: t)
                Haptics.success()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Profile header

    @ViewBuilder
    private var profileHeader: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            FriendAvatar(friend: currentFriend, size: 68)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(currentFriend.displayName)
                    .font(AppTheme.Typography.title)

                Button {
                    UIPasteboard.general.string = currentFriend.identifier
                    Haptics.selection()
                    withAnimation(AppTheme.Animation.springFast) { showCopiedFeedback = true }
                    Task {
                        try? await Task.sleep(for: AppTheme.Timing.copyFeedback)
                        withAnimation(AppTheme.Animation.easeOut) { showCopiedFeedback = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if showCopiedFeedback {
                            Label("Copied!", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label(currentFriend.identifier, systemImage: "doc.on.doc")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(AppTheme.Typography.mono)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .contentTransition(.identity)
                }
                .buttonStyle(.plain)
                .animation(AppTheme.Animation.springFast, value: showCopiedFeedback)
                .accessibilityLabel(showCopiedFeedback ? "Identifier copied" : "Copy identifier")
                .accessibilityHint("Copies the friend's identifier to the clipboard")

                Text(addedDateString)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.tertiary)

                if let about = currentFriend.about {
                    Text(about)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(AppTheme.Spacing.md)
        .glassSurface(cornerRadius: AppTheme.Corner.xl)
        .glassEffectID("profile-\(friend.id)", in: glassNS)
    }
}
