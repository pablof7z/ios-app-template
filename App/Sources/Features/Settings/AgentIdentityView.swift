import SwiftUI
import UIKit

struct AgentIdentityView: View {
    @Environment(AppStateStore.self) private var store

    @State private var settings: Settings = Settings()
    @State private var hasPrivateKey: Bool = false
    @State private var showCopied: Bool = false
    @State private var showRegenerateConfirm: Bool = false
    @State private var importKeyInput: String = ""
    @State private var showImportKey: Bool = false
    @State private var showQRFullScreen: Bool = false
    @State private var editingPictureURL: Bool = false
    @State private var keyManagementExpanded: Bool = false
    @FocusState private var nameFocused: Bool
    @FocusState private var bioFocused: Bool

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.15), Color.clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 280)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    heroSection.padding(.top, 24)
                    cardsSection.padding(.top, 16)
                    footerNote
                }
            }
        }
        .navigationTitle("Identity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showQRFullScreen = true } label: {
                    Image(systemName: "qrcode")
                }
                .disabled(!hasPrivateKey)
            }
        }
        .onAppear {
            settings = store.state.settings
            refreshKeyState()
            keyManagementExpanded = !hasPrivateKey
        }
        .onChange(of: settings) { _, new in store.updateSettings(new) }
        .alert("Regenerate Key Pair?", isPresented: $showRegenerateConfirm) {
            Button("Regenerate", role: .destructive) { generateKeyPair(); Haptics.success() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently replaces your current Nostr identity. Friends who know your old key will no longer recognize you.")
        }
        .fullScreenCover(isPresented: $showQRFullScreen) {
            AgentIdentityQRView(npub: npubFull, name: settings.nostrProfileName)
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $editingPictureURL) {
            AgentPictureURLSheet(pictureURL: $settings.nostrProfilePicture, isPresented: $editingPictureURL)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 0) {
            avatarView
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                .overlay(alignment: .bottomTrailing) {
                    Button { editingPictureURL = true } label: {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .frame(width: 28, height: 28)
                    }
                    .glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
                    .offset(x: 4, y: 4)
                }

            nameField.padding(.top, 16).padding(.horizontal, 32)

            if hasPrivateKey && !npubFull.isEmpty {
                npubChip.padding(.top, 8)
            }

            bioField.padding(.top, 8).padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var nameField: some View {
        if nameFocused {
            TextField("Name your agent", text: $settings.nostrProfileName)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .focused($nameFocused)
                .submitLabel(.done)
        } else {
            Text(settings.nostrProfileName.isEmpty ? "Name your agent" : settings.nostrProfileName)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(settings.nostrProfileName.isEmpty ? .tertiary : .primary)
                .multilineTextAlignment(.center)
                .onTapGesture { nameFocused = true }
        }
    }

    @ViewBuilder
    private var bioField: some View {
        if bioFocused {
            TextField("A short bio…", text: $settings.nostrProfileAbout, axis: .vertical)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2...5)
                .focused($bioFocused)
                .submitLabel(.done)
                .frame(maxWidth: 320)
        } else {
            Text(settings.nostrProfileAbout.isEmpty ? "Add a bio…" : settings.nostrProfileAbout)
                .font(.callout)
                .foregroundStyle(settings.nostrProfileAbout.isEmpty ? .tertiary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2...5)
                .frame(maxWidth: 320)
                .onTapGesture { bioFocused = true }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let url = validPictureURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: avatarPlaceholder
                }
            }
            .clipShape(Circle())
        } else {
            avatarPlaceholder.clipShape(Circle())
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle().fill(LinearGradient(
                colors: [.purple.opacity(0.8), .blue.opacity(0.7)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            Text(nameInitial)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var npubChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "qrcode").font(.caption2)
            Text(formattedNpubShort).font(.system(.caption, design: .monospaced))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .glassEffect(.regular, in: .capsule)
        .onLongPressGesture { UIPasteboard.general.string = npubFull; Haptics.selection() }
        .onTapGesture { showQRFullScreen = true }
    }

    // MARK: - Cards

    private var cardsSection: some View {
        GlassEffectContainer(spacing: 16) {
            if hasPrivateKey {
                identityCard
            } else {
                generateKeyCard
            }
            AgentRelayCard(relayURL: $settings.nostrRelayURL)
            AgentKeyManagementCard(
                hasPrivateKey: hasPrivateKey,
                showCopied: showCopied,
                npubEmpty: npubFull.isEmpty,
                isExpanded: $keyManagementExpanded,
                showImportKey: $showImportKey,
                importKeyInput: $importKeyInput,
                onCopyPublicKey: copyPublicKey,
                onRegenerate: { showRegenerateConfirm = true },
                onGenerate: { generateKeyPair(); Haptics.success() },
                onImport: importPrivateKey
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var identityCard: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Color.white.clipShape(RoundedRectangle(cornerRadius: 16))
                    QRCodeView(content: npubFull).padding(8)
                }
                .frame(width: 112, height: 112)
                .onTapGesture { showQRFullScreen = true }

                Button { showQRFullScreen = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .offset(x: 6, y: -6)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Public key")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .textCase(.uppercase).kerning(0.5)
                Text(npubFull.isEmpty ? "—" : npubFull)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary).lineLimit(3)
                HStack(spacing: 8) {
                    Button { showQRFullScreen = true } label: {
                        Label("QR", systemImage: "qrcode").font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)

                    Button { copyPublicKey() } label: {
                        Label(showCopied ? "Copied" : "Copy",
                              systemImage: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .disabled(npubFull.isEmpty)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassSurface(cornerRadius: 24, interactive: true)
    }

    private var generateKeyCard: some View {
        VStack(spacing: 12) {
            Text("No identity yet")
                .font(.system(.headline, design: .rounded, weight: .semibold))
            Text("Generate a key pair to create your Nostr identity.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { generateKeyPair(); Haptics.success() } label: {
                Label("Generate Key Pair", systemImage: "key.fill")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .glassSurface(cornerRadius: 24)
    }

    private var footerNote: some View {
        Text("Private key is stored in Keychain and never leaves this device.")
            .font(.caption2).foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32).padding(.vertical, 16)
    }

    // MARK: - Computed

    private var validPictureURL: URL? {
        let trimmed = settings.nostrProfilePicture.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }

    private var nameInitial: String {
        guard let first = settings.nostrProfileName.first else { return "?" }
        return String(first).uppercased()
    }

    private var formattedNpubShort: String {
        guard let hex = settings.nostrPublicKeyHex, !hex.isEmpty else { return "" }
        let npub = "npub1" + hex
        guard npub.count > 14 else { return npub }
        return "\(npub.prefix(10))…\(npub.suffix(6))"
    }

    private var npubFull: String {
        guard let hex = settings.nostrPublicKeyHex, !hex.isEmpty else { return "" }
        return "npub1" + hex
    }

    // MARK: - Actions

    private func generateKeyPair() {
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
        settings.nostrPublicKeyHex = String(trimmed.reversed())
        importKeyInput = ""
        refreshKeyState()
        Haptics.success()
    }

    private func copyPublicKey() {
        guard !npubFull.isEmpty else { return }
        UIPasteboard.general.string = npubFull
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
