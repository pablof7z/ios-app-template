import SwiftUI

// MARK: - Shared display constants

/// Display constants shared across Agent peer-management views.
enum NostrPubkeyDisplay {
    /// Number of hex characters shown in a truncated pubkey preview.
    static let prefixLength = 16
}

// MARK: - Relay Card

struct AgentRelayCard: View {
    @Binding var relayURL: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                Text("Relay")
                    .font(AppTheme.Typography.headline)
                Spacer()
            }

            TextField("wss://relay.damus.io", text: $relayURL)
                .font(.callout.monospaced())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .padding(10)
                .background(Color(.quaternarySystemFill), in: RoundedRectangle(cornerRadius: AppTheme.Corner.md))

            Text("Your agent connects here to send and receive Nostr messages.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(AppTheme.Spacing.md)
        .glassSurface(cornerRadius: AppTheme.Corner.xl)
    }
}

// MARK: - Key Management Card

struct AgentKeyManagementCard: View {
    let hasPrivateKey: Bool
    let showCopied: Bool
    let npubEmpty: Bool
    @Binding var isExpanded: Bool
    @Binding var showImportKey: Bool
    @Binding var importKeyInput: String
    let onCopyPublicKey: () -> Void
    let onRegenerate: () -> Void
    let onGenerate: () -> Void
    let onImport: () -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 12) {
                if hasPrivateKey {
                    Button {
                        onCopyPublicKey()
                    } label: {
                        Label(
                            showCopied ? "Copied" : "Copy Public Key",
                            systemImage: showCopied ? "checkmark" : "doc.on.doc"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(npubEmpty)

                    Button(role: .destructive) {
                        onRegenerate()
                    } label: {
                        Label("Regenerate Key Pair", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Button {
                        onGenerate()
                    } label: {
                        Label("Generate Key Pair", systemImage: "key.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                importSection
            }
            .padding(.top, 8)
        } label: {
            Label("Key Management", systemImage: "key.fill")
                .font(AppTheme.Typography.body)
        }
        .padding(AppTheme.Spacing.md)
        .glassSurface(cornerRadius: AppTheme.Corner.xl)
    }

    private var importSection: some View {
        DisclosureGroup("Import Private Key", isExpanded: $showImportKey) {
            VStack(spacing: 8) {
                SecureField("Paste private key hex…", text: $importKeyInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.callout.monospaced())
                    .padding(10)
                    .background(Color(.quaternarySystemFill), in: RoundedRectangle(cornerRadius: AppTheme.Corner.md))

                Button("Import") {
                    onImport()
                }
                .disabled(importKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Picture URL Sheet

struct AgentPictureURLSheet: View {
    @Binding var pictureURL: String
    @Binding var isPresented: Bool

    private var validPictureURL: URL? {
        let trimmed = pictureURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                avatarPreview
                    .padding(.top, 8)

                TextField("https://…", text: $pictureURL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppTheme.Corner.md))
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button("Clear") {
                        pictureURL = ""
                        isPresented = false
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)

                    Button("Done") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Profile Picture")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.fraction(0.35)])
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let url = validPictureURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholderCircle
                }
            }
            .frame(width: AppTheme.Layout.iconLg, height: AppTheme.Layout.iconLg)
            .clipShape(Circle())
        } else {
            placeholderCircle
                .frame(width: AppTheme.Layout.iconLg, height: AppTheme.Layout.iconLg)
        }
    }

    private var placeholderCircle: some View {
        Circle()
            .fill(Color.secondary.opacity(0.15))
            .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
    }
}
