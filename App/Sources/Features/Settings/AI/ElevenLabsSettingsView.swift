import SwiftUI

private let elevenLabsTint = Color(red: 0, green: 0.78, blue: 0.62)

struct ElevenLabsSettingsView: View {
    @Environment(AppStateStore.self) private var store

    @State private var settings: Settings = Settings()
    @State private var showManualAPIKey = false
    @State private var manualAPIKey = ""
    @State private var hasStoredKey = false
    @State private var isConnectingBYOK = false
    @State private var credentialMessage: String?
    @State private var credentialError: String?
    @State private var byokConnect = BYOKConnectService()

    var body: some View {
        Form {
            heroSection
            connectionSection
            modelsSection
            voiceSection
        }
        .navigationTitle("ElevenLabs")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            settings = store.state.settings
            refreshCredentialState()
        }
        .onChange(of: settings) { _, new in store.updateSettings(new) }
    }

    // MARK: - Sections

    private var heroSection: some View {
        Section {
            ElevenLabsHeroCard(
                connectionState: connectionState,
                keyLabel: settings.elevenLabsBYOKKeyLabel,
                connectedAt: settings.elevenLabsConnectedAt
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private var connectionSection: some View {
        Section {
            Label(statusTitle, systemImage: statusIcon)

            Button {
                Task { await connectWithBYOK() }
            } label: {
                Label(isConnectingBYOK ? "Connecting..." : byokButtonTitle, systemImage: "key.viewfinder")
            }
            .buttonStyle(.glassProminent)
            .tint(elevenLabsTint)
            .disabled(isConnectingBYOK)

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

            Button {
                saveManualKey()
            } label: {
                Label("Save Manual Key", systemImage: "square.and.arrow.down")
            }
            .disabled(manualAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if hasStoredKey {
                Button(role: .destructive) {
                    disconnectElevenLabs()
                } label: {
                    Label("Disconnect ElevenLabs", systemImage: "trash")
                }
            }

            if let credentialMessage {
                Text(credentialMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let credentialError {
                Text(credentialError)
                    .font(.caption)
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
    }

    private var modelsSection: some View {
        Section {
            LabeledContent("STT Model") {
                TextField("scribe_v1", text: $settings.elevenLabsSTTModel)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.callout.monospaced())
            }
            LabeledContent("TTS Model") {
                TextField("eleven_turbo_v2_5", text: $settings.elevenLabsTTSModel)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.callout.monospaced())
            }
        } header: {
            Text("Models")
        } footer: {
            Text("Model IDs are passed verbatim to the ElevenLabs API.")
        }
    }

    private var voiceSection: some View {
        Section {
            NavigationLink {
                ElevenLabsVoiceBrowserView()
            } label: {
                SettingsRow(
                    icon: "waveform.and.mic",
                    tint: elevenLabsTint,
                    title: "Voice",
                    value: store.state.settings.elevenLabsVoiceID.isEmpty ? "Not set" : "Selected"
                )
            }
        } header: {
            Text("Voice")
        } footer: {
            Text("Browse the ElevenLabs voice library and preview samples.")
        }
    }

    // MARK: - Derived state

    private var connectionState: ElevenLabsConnectionState {
        ElevenLabsConnectionState.derive(
            source: settings.elevenLabsCredentialSource,
            hasKey: hasStoredKey
        )
    }

    private var byokButtonTitle: String {
        settings.elevenLabsCredentialSource == .byok ? "Reconnect BYOK" : "Connect with BYOK"
    }

    private var statusTitle: String {
        guard hasStoredKey else {
            return settings.elevenLabsCredentialSource == .none ? "Not connected" : "Reconnect required"
        }
        switch settings.elevenLabsCredentialSource {
        case .byok:   return "Connected with BYOK"
        case .manual: return "Manual key saved"
        case .none:   return "Key stored"
        }
    }

    private var statusIcon: String {
        guard hasStoredKey else {
            return settings.elevenLabsCredentialSource == .none ? "waveform.circle" : "exclamationmark.triangle"
        }
        return "waveform.circle.fill"
    }

    // MARK: - Credential actions

    private func connectWithBYOK() async {
        credentialError = nil
        credentialMessage = nil
        isConnectingBYOK = true
        defer { isConnectingBYOK = false }

        do {
            let token = try await byokConnect.connectElevenLabs()
            try ElevenLabsCredentialStore.saveAPIKey(token.apiKey)
            settings.markElevenLabsBYOK(keyID: token.keyID, keyLabel: token.keyLabel)
            store.updateSettings(settings)
            manualAPIKey = ""
            refreshCredentialState()
            credentialMessage = "ElevenLabs connected with BYOK."
            Haptics.success()
        } catch {
            credentialError = error.localizedDescription
        }
    }

    private func saveManualKey() {
        credentialError = nil
        credentialMessage = nil
        do {
            try ElevenLabsCredentialStore.saveAPIKey(manualAPIKey)
            settings.markElevenLabsManual()
            store.updateSettings(settings)
            manualAPIKey = ""
            refreshCredentialState()
            credentialMessage = "ElevenLabs key saved in Keychain."
            Haptics.success()
        } catch {
            credentialError = "ElevenLabs key could not be saved."
        }
    }

    private func disconnectElevenLabs() {
        credentialError = nil
        credentialMessage = nil
        do {
            try ElevenLabsCredentialStore.deleteAPIKey()
            settings.clearElevenLabsCredential()
            store.updateSettings(settings)
            manualAPIKey = ""
            refreshCredentialState()
            credentialMessage = "ElevenLabs disconnected."
            Haptics.success()
        } catch {
            credentialError = "ElevenLabs key could not be deleted."
        }
    }

    private func refreshCredentialState() {
        hasStoredKey = ElevenLabsCredentialStore.hasAPIKey()
    }
}
