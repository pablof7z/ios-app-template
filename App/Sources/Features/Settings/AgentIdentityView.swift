import SwiftUI
import UIKit

struct AgentIdentityView: View {
    @Environment(AppStateStore.self) private var store

    @State private var settings: Settings = Settings()
    @State private var hasPrivateKey: Bool = false
    @State private var showCopied: Bool = false
    @State private var showRegenerateConfirm: Bool = false
    @State private var importKeyInput: String = ""

    var body: some View {
        Form {
            profileSection
            keypairSection
            relaySection
        }
        .navigationTitle("Identity & Profile")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            settings = store.state.settings
            refreshKeyState()
        }
        .onChange(of: settings) { _, new in store.updateSettings(new) }
        .alert("Regenerate Key Pair?", isPresented: $showRegenerateConfirm) {
            Button("Regenerate", role: .destructive) {
                generateKeyPair()
                Haptics.success()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently replaces your current Nostr identity. Friends who know your old key will no longer recognize you.")
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            LabeledContent("Name") {
                TextField("Agent Name", text: $settings.nostrProfileName)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
            }

            LabeledContent("About") {
                TextField(
                    "A brief description",
                    text: $settings.nostrProfileAbout,
                    axis: .vertical
                )
                .lineLimit(3, reservesSpace: true)
                .multilineTextAlignment(.trailing)
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                profileAvatar
                LabeledContent("Picture URL") {
                    TextField("https://…", text: $settings.nostrProfilePicture)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .font(.callout.monospaced())
                }
            }
        } header: {
            Text("Profile")
        }
    }

    @ViewBuilder
    private var profileAvatar: some View {
        if let url = validPictureURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    avatarPlaceholder
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        } else {
            avatarPlaceholder
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle().fill(Color.secondary.opacity(0.15))
            Image(systemName: "person.fill")
                .foregroundStyle(.secondary)
        }
    }

    private var validPictureURL: URL? {
        let trimmed = settings.nostrProfilePicture.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }

    // MARK: - Keypair

    private var keypairSection: some View {
        Section {
            if hasPrivateKey {
                if settings.nostrPublicKeyHex?.isEmpty == false {
                    LabeledContent("Public Key") {
                        Text(formattedPubkey)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Button {
                    copyPublicKey()
                } label: {
                    Label(showCopied ? "Copied" : "Copy Public Key",
                          systemImage: showCopied ? "checkmark" : "doc.on.doc")
                }
                .disabled(settings.nostrPublicKeyHex?.isEmpty ?? true)
                .accessibilityLabel(showCopied ? "Copied" : "Copy public key")

                Button(role: .destructive) {
                    showRegenerateConfirm = true
                } label: {
                    Label("Regenerate Key", systemImage: "arrow.triangle.2.circlepath")
                }
            } else {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Your Nostr identity lets your agent send and receive messages on the Nostr network.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        generateKeyPair()
                        Haptics.success()
                    } label: {
                        Label("Generate Key Pair", systemImage: "key.fill")
                    }

                    HStack {
                        TextField("Paste private key hex…", text: $importKeyInput)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.callout.monospaced())
                        Button("Import") {
                            importPrivateKey()
                        }
                        .disabled(importKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        } header: {
            Text("Keypair")
        } footer: {
            Text("Private key is stored in Keychain and never leaves this device.")
        }
    }

    private var formattedPubkey: String {
        guard let hex = settings.nostrPublicKeyHex, !hex.isEmpty else {
            return "—"
        }
        return "npub1\(hex.prefix(16))…"
    }

    // MARK: - Relay

    private var relaySection: some View {
        Section {
            LabeledContent("Relay URL") {
                TextField("wss://relay.damus.io", text: $settings.nostrRelayURL)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .font(.callout.monospaced())
            }
        } header: {
            Text("Relay")
        } footer: {
            Text("The Nostr relay your agent connects to for sending and receiving messages.")
        }
    }

    // MARK: - Actions

    private func generateKeyPair() {
        // TODO: Replace with real secp256k1 derivation (e.g. swift-secp256k1)
        let privkeyBytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        let privkeyHex = privkeyBytes.map { String(format: "%02x", $0) }.joined()
        let pubkeyHex = privkeyBytes.reversed().map { String(format: "%02x", $0) }.joined()
        try? NostrCredentialStore.savePrivateKey(privkeyHex)
        settings.nostrPublicKeyHex = pubkeyHex
        refreshKeyState()
    }

    private func importPrivateKey() {
        let trimmed = importKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        try? NostrCredentialStore.savePrivateKey(trimmed)
        // TODO: Replace with real secp256k1 derivation (e.g. swift-secp256k1)
        settings.nostrPublicKeyHex = String(trimmed.reversed())
        importKeyInput = ""
        refreshKeyState()
        Haptics.success()
    }

    private func copyPublicKey() {
        guard let hex = settings.nostrPublicKeyHex, !hex.isEmpty else { return }
        UIPasteboard.general.string = hex
        Haptics.selection()
        showCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run { showCopied = false }
        }
    }

    private func refreshKeyState() {
        hasPrivateKey = NostrCredentialStore.hasPrivateKey()
    }
}
