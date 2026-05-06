import SwiftUI
import UIKit

private enum AgentBlockedConstants {
    /// How long (in seconds) the "Copied" confirmation badge stays visible.
    static let copyFeedbackDuration: Duration = .seconds(1.2)
}

struct AgentBlockedView: View {
    @Environment(AppStateStore.self) private var store

    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var copiedKey: String?

    private var sortedBlocked: [String] {
        store.state.nostrBlockedPubkeys.sorted()
    }

    private var filteredBlocked: [String] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sortedBlocked }
        return sortedBlocked.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        Form {
            if sortedBlocked.isEmpty {
                ContentUnavailableView {
                    Label("No blocked peers", systemImage: "nosign")
                } description: {
                    Text("Peers you block can never contact your agent.")
                } actions: {
                    Button("Block a peer") { showAddSheet = true }
                        .buttonStyle(.glassProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(filteredBlocked, id: \.self) { key in
                        BlockedRow(
                            key: key,
                            isCopied: copiedKey == key,
                            onTap: { copy(key) }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.removeFromNostrBlocklist(key)
                                Haptics.selection()
                            } label: {
                                Label("Unblock", systemImage: "checkmark.circle")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle(sortedBlocked.isEmpty ? "Blocked" : "Blocked (\(sortedBlocked.count))")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search blocked peers")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            BlockPeerSheet { hex in
                store.blockNostrPubkey(hex)
                Haptics.success()
            }
        }
    }

    private func copy(_ key: String) {
        UIPasteboard.general.string = key
        Haptics.selection()
        copiedKey = key
        Task {
            try? await Task.sleep(for: AgentBlockedConstants.copyFeedbackDuration)
            await MainActor.run {
                if copiedKey == key { copiedKey = nil }
            }
        }
    }
}

// MARK: - BlockedRow

private struct BlockedRow: View {
    let key: String
    let isCopied: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "nosign")
                    .foregroundStyle(.red)

                Text("npub1\(key.prefix(NostrPubkeyDisplay.prefixLength))…")
                    .font(.callout.monospaced())
                    .foregroundStyle(.primary)

                Spacer()

                if isCopied {
                    Label("Copied", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .animation(AppTheme.Animation.easeOut, value: isCopied)
    }
}

// MARK: - BlockPeerSheet

private struct BlockPeerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hexInput: String = ""
    let onBlock: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Hex pubkey…", text: $hexInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.callout.monospaced())
                } footer: {
                    Text("Paste a Nostr public key in hex format. The peer will be blocked from contacting your agent.")
                }
            }
            .navigationTitle("Block Peer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Block") {
                        let trimmed = hexInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        guard !trimmed.isEmpty else { return }
                        onBlock(trimmed)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(hexInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
