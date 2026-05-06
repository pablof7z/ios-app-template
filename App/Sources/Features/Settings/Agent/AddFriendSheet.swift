import SwiftUI

// MARK: - AddFriendSheet

/// Sheet for adding a friend by scanning their Nostr QR code or pasting their public key.
struct AddFriendSheet: View {
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
                .strokeBorder(.white.opacity(0.6), lineWidth: AgentFriendsConstants.viewfinderLineWidth)
                .frame(width: AgentFriendsConstants.viewfinderSize, height: AgentFriendsConstants.viewfinderSize)
            Spacer()
        }
    }

    private var instructionPill: some View {
        VStack {
            Spacer()
            Text("Point at a Nostr QR code")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, AgentFriendsConstants.pillHorizontalPadding)
                .padding(.vertical, AgentFriendsConstants.pillVerticalPadding)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, AgentFriendsConstants.pillBottomPadding)
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

    // MARK: - Actions

    private func add() {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValid else { return }
        _ = store.addFriend(displayName: name, identifier: cleanedIdentifier)
        Haptics.success()
        dismiss()
    }
}
