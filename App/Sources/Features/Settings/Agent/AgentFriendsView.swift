import SwiftUI

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
        HStack(alignment: .top, spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.headline)

                Text(friend.shortIdentifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                if let about = friend.about, !about.isEmpty {
                    Text(about)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Text(friend.addedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
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
            .frame(width: 40, height: 40)
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
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 40, height: 40)
    }
}

// MARK: - AddFriendSheet

private struct AddFriendSheet: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var identifier = ""
    @FocusState private var focusedField: Field?

    private enum Field { case name, identifier }

    private var cleanedIdentifier: String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.hasPrefix("npub1") {
            return String(trimmed.dropFirst("npub1".count))
        }
        return trimmed
    }

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && cleanedIdentifier.count >= 32
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display name", text: $displayName)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .identifier }

                    TextField("npub or hex pubkey", text: $identifier)
                        .focused($focusedField, equals: .identifier)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.callout.monospaced())
                } footer: {
                    Text("Paste your friend's Nostr public key. Both npub1… and raw hex are accepted.")
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .onAppear { focusedField = .name }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func add() {
        guard isValid else { return }
        _ = store.addFriend(displayName: trimmedName, identifier: cleanedIdentifier)
        Haptics.success()
        dismiss()
    }
}
