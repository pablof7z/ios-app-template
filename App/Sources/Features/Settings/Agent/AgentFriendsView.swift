import SwiftUI

private enum AgentFriendsConstants {
    /// Diameter of the avatar circle used in friend list rows and initials placeholders.
    static let avatarSize: CGFloat = 40
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
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: AgentFriendsConstants.avatarSize, height: AgentFriendsConstants.avatarSize)
    }
}

// MARK: - AddFriendSheet

private struct AddFriendSheet: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .camera
    @State private var displayName = ""
    @State private var identifier = ""
    @State private var scanned = false
    @FocusState private var nameFocused: Bool

    private enum Mode { case camera, paste }

    private var cleanedIdentifier: String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("npub1") {
            return String(trimmed.dropFirst("npub1".count))
        }
        return trimmed
    }

    private var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        cleanedIdentifier.count >= 32
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if mode == .camera {
                    cameraPanel
                } else {
                    pastePanel
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(mode == .camera ? "Paste" : "Camera") {
                        withAnimation { mode = mode == .camera ? .paste : .camera }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if mode == .paste {
                        Button("Add") { add() }
                            .fontWeight(.semibold)
                            .disabled(!isValid)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Camera panel

    private var cameraPanel: some View {
        ZStack {
            scannerLayer
            viewfinderFrame
            instructionPill
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scannerLayer: some View {
        QRCodeScannerView { value in
            guard !scanned else { return }
            scanned = true
            Haptics.success()
            identifier = value
            mode = .paste
            nameFocused = true
        }
        .ignoresSafeArea()
    }

    private var viewfinderFrame: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: AppTheme.Corner.lg, style: .continuous)
                .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                .frame(width: 200, height: 200)
            Spacer()
        }
    }

    private var instructionPill: some View {
        VStack {
            Spacer()
            Text("Point at a Nostr QR code")
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 32)
        }
    }

    // MARK: - Paste panel

    private var pastePanel: some View {
        Form {
            Section {
                TextField("Display name", text: $displayName)
                    .focused($nameFocused)
                    .submitLabel(.next)

                TextField("npub or hex pubkey", text: $identifier)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.callout.monospaced())
            } footer: {
                Text("Both npub1… and raw hex pubkeys are accepted.")
            }
        }
        .onAppear { if !scanned { nameFocused = true } }
    }

    private func add() {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValid else { return }
        _ = store.addFriend(displayName: name, identifier: cleanedIdentifier)
        Haptics.success()
        dismiss()
    }
}
