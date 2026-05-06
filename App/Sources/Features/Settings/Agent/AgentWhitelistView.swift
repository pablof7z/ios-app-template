import SwiftUI
import UIKit

private enum AgentWhitelistConstants {
    /// How long (in seconds) the "Copied" confirmation badge stays visible.
    static let copyFeedbackDuration: Duration = .seconds(1.2)
}

struct AgentWhitelistView: View {
    @Environment(AppStateStore.self) private var store

    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var copiedKey: String?

    var body: some View {
        Form {
            if !pendingApprovals.isEmpty {
                pendingSection
            }

            allowedSection

            if pendingApprovals.isEmpty && filteredAllowed.isEmpty && searchText.isEmpty {
                ContentUnavailableView {
                    Label("No allowed peers", systemImage: "checkmark.shield")
                } description: {
                    Text("Peers who contact your agent will appear here for approval.")
                } actions: {
                    Button("Allow a peer") { showAddSheet = true }
                        .buttonStyle(.glassProminent)
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Whitelist")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search allowed peers")
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
            AllowPeerSheet { hex in
                store.allowNostrPubkey(hex)
                Haptics.success()
            }
        }
    }

    // MARK: - Pending Approval

    private var pendingApprovals: [NostrPendingApproval] {
        store.pendingNostrApprovals
    }

    private var pendingSection: some View {
        Section("Pending Approval") {
            ForEach(pendingApprovals) { approval in
                PendingApprovalRow(
                    approval: approval,
                    onAllow: {
                        store.allowNostrPubkey(approval.pubkeyHex)
                        Haptics.success()
                    },
                    onBlock: {
                        store.blockNostrPubkey(approval.pubkeyHex)
                        Haptics.selection()
                    },
                    onDismiss: {
                        store.dismissNostrPendingApproval(approval.id)
                        Haptics.selection()
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        store.allowNostrPubkey(approval.pubkeyHex)
                        Haptics.success()
                    } label: {
                        Label("Allow", systemImage: "checkmark.circle.fill")
                    }
                    .tint(.green)

                    Button {
                        store.blockNostrPubkey(approval.pubkeyHex)
                        Haptics.selection()
                    } label: {
                        Label("Block", systemImage: "nosign")
                    }
                    .tint(.red)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        store.dismissNostrPendingApproval(approval.id)
                        Haptics.selection()
                    } label: {
                        Label("Dismiss", systemImage: "xmark")
                    }
                    .tint(.gray)
                }
            }
        }
    }

    // MARK: - Allowed

    private var sortedAllowed: [String] {
        store.state.nostrAllowedPubkeys.sorted()
    }

    private var filteredAllowed: [String] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sortedAllowed }
        return sortedAllowed.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    @ViewBuilder
    private var allowedSection: some View {
        if !sortedAllowed.isEmpty {
            Section("Allowed") {
                ForEach(filteredAllowed, id: \.self) { key in
                    AllowedRow(
                        key: key,
                        isCopied: copiedKey == key,
                        onTap: { copy(key) }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.removeFromNostrAllowlist(key)
                            Haptics.selection()
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            .animation(AppTheme.Animation.springFast, value: store.state.nostrAllowedPubkeys.count)
        }
    }

    private func copy(_ key: String) {
        UIPasteboard.general.string = key
        Haptics.selection()
        copiedKey = key
        Task {
            try? await Task.sleep(for: AgentWhitelistConstants.copyFeedbackDuration)
            await MainActor.run {
                if copiedKey == key { copiedKey = nil }
            }
        }
    }
}

// PendingApprovalRow, AllowedRow, and AllowPeerSheet have been extracted to AgentWhitelistRows.swift.
