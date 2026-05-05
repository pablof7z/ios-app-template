import SwiftUI
import UIKit

private enum AgentWhitelistConstants {
    /// Number of hex characters shown in the truncated pubkey preview.
    static let pubkeyPrefixLength = 16
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
                PendingApprovalRow(approval: approval)
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

// MARK: - PendingApprovalRow

private struct PendingApprovalRow: View {
    let approval: NostrPendingApproval

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            ZStack {
                Circle().fill(LinearGradient(
                    colors: [.orange.opacity(0.3), .orange.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                Image(systemName: "person.fill")
                    .foregroundStyle(.orange)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(approval.displayName ?? "Unknown")
                    .font(.headline)

                Text(approval.shortPubkey)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Text(approval.receivedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - AllowedRow

private struct AllowedRow: View {
    let key: String
    let isCopied: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)

                Text("npub1\(key.prefix(AgentWhitelistConstants.pubkeyPrefixLength))…")
                    .font(.callout.monospaced())
                    .foregroundStyle(.primary)

                Spacer()

                if isCopied {
                    Label("Copied", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
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

// MARK: - AllowPeerSheet

private struct AllowPeerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hexInput: String = ""
    let onAllow: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Hex pubkey…", text: $hexInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.callout.monospaced())
                } footer: {
                    Text("Paste a Nostr public key in hex format. The peer will be allowed to contact your agent.")
                }
            }
            .navigationTitle("Allow Peer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Allow") {
                        let trimmed = hexInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        guard !trimmed.isEmpty else { return }
                        onAllow(trimmed)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(hexInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
