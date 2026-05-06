import SwiftUI

/// The "Connection" section of ElevenLabsSettingsView.
///
/// Extracted to keep `ElevenLabsSettingsView` under the 300-line soft limit.
/// All mutable state is owned by the parent and passed in via bindings and closures.
struct ElevenLabsConnectionSection: View {
    // MARK: - State from parent

    let statusTitle: String
    let statusIcon: String
    let byokButtonTitle: String
    let isConnectingBYOK: Bool
    let isValidatingKey: Bool
    let hasStoredKey: Bool
    let keyInfo: ElevenLabsKeyInfo?
    let credentialMessage: String?
    let credentialError: String?

    @Binding var manualAPIKey: String
    @Binding var showManualAPIKey: Bool

    // MARK: - Actions

    let onConnectBYOK: () -> Void
    let onSaveManualKey: () -> Void
    let onDisconnect: () -> Void
    let onValidateKey: () -> Void

    // MARK: - Body

    var body: some View {
        Section {
            Label(statusTitle, systemImage: statusIcon)

            Button(action: onConnectBYOK) {
                Label(isConnectingBYOK ? "Connecting..." : byokButtonTitle, systemImage: "key.viewfinder")
            }
            .buttonStyle(.glassProminent)
            .tint(AppTheme.Brand.elevenLabsTint)
            .disabled(isConnectingBYOK)

            apiKeyField

            Button(action: onSaveManualKey) {
                Label("Save Manual Key", systemImage: "square.and.arrow.down")
            }
            .disabled(manualAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if hasStoredKey {
                Button(role: .destructive, action: onDisconnect) {
                    Label("Disconnect ElevenLabs", systemImage: "trash")
                }
            }

            if hasStoredKey {
                Button(action: onValidateKey) {
                    HStack {
                        Label(
                            isValidatingKey ? "Validating…" : "Validate Key",
                            systemImage: "checkmark.shield"
                        )
                        if isValidatingKey {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isValidatingKey)
                .tint(AppTheme.Brand.elevenLabsTint)
            }

            if let keyInfo {
                ElevenLabsKeyInfoCard(info: keyInfo)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let credentialMessage {
                Text(credentialMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let credentialError {
                Text(credentialError)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        } header: {
            Text("Connection")
        } footer: {
            Text("BYOK opens byok.f7z.io for consent and stores the returned ElevenLabs key in Keychain. Manual keys are also saved only in Keychain.")
        }
        .animation(.default, value: credentialMessage)
        .animation(.default, value: credentialError)
        .animation(.default, value: keyInfo?.tier)
    }

    // MARK: - Subviews

    private var apiKeyField: some View {
        HStack {
            if showManualAPIKey {
                TextField("xi-…", text: $manualAPIKey)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                SecureField("Paste ElevenLabs API Key", text: $manualAPIKey)
            }
            Button {
                showManualAPIKey.toggle()
            } label: {
                Image(systemName: showManualAPIKey ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showManualAPIKey ? "Hide API key" : "Show API key")
        }
    }
}
