import SwiftUI
import UIKit

struct AgentBlockedView: View {
    @Environment(AppStateStore.self) private var store

    @State private var searchText = ""
    @State private var showAddSheet = false

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
                ContentUnavailableView(
                    "No blocked peers",
                    systemImage: "nosign",
                    description: Text("Peers you block can never contact your agent.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(filteredBlocked, id: \.self) { key in
                        BlockedRow(key: key)
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
}

// MARK: - BlockedRow

private struct BlockedRow: View {
    let key: String

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: "nosign")
                .foregroundStyle(.red)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("npub1\(key.prefix(16))…")
                    .font(.body)

                Text(key)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 2)
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
