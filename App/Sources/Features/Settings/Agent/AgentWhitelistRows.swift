import SwiftUI
import UIKit

// MARK: - PendingApprovalRow

struct PendingApprovalRow: View {
    let approval: NostrPendingApproval
    let onAllow: () -> Void
    let onBlock: () -> Void
    let onDismiss: () -> Void

    @State private var pubkeyCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle().fill(LinearGradient(
                        colors: [.orange.opacity(0.3), .orange.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    Image(systemName: "person.fill")
                        .foregroundStyle(.orange)
                }
                .frame(width: AppTheme.Layout.iconSm, height: AppTheme.Layout.iconSm)

                VStack(alignment: .leading, spacing: 2) {
                    Text(approval.displayName ?? "Unknown")
                        .font(AppTheme.Typography.headline)

                    Button {
                        UIPasteboard.general.string = approval.pubkeyHex
                        Haptics.selection()
                        pubkeyCopied = true
                        Task {
                            try? await Task.sleep(for: AppTheme.Timing.copyFeedback)
                            await MainActor.run { pubkeyCopied = false }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(approval.shortPubkey)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            if pubkeyCopied {
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .animation(AppTheme.Animation.springFast, value: pubkeyCopied)
                    }
                    .buttonStyle(.plain)

                    Text(approval.receivedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }

            // Inline action buttons — swipe actions are also available
            HStack(spacing: AppTheme.Spacing.sm) {
                Button(action: onAllow) {
                    Label("Allow", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button(action: onBlock) {
                    Label("Block", systemImage: "nosign")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button(action: onDismiss) {
                    Label("Dismiss", systemImage: "xmark")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AllowedRow

struct AllowedRow: View {
    let key: String
    let isCopied: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)

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

// MARK: - AllowPeerSheet

struct AllowPeerSheet: View {
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
