import SwiftUI

/// Main hub screen for OpenRouter configuration.
/// Covers model selection, BYOK / manual key management, and connection status.
struct OpenRouterSettingsView: View {
    @Environment(AppStateStore.self) private var store

    @State private var settings: Settings = Settings()
    @State private var showManualAPIKey = false
    @State private var manualAPIKey = ""
    @State private var hasStoredOpenRouterKey = false
    @State private var isConnectingBYOK = false
    @State private var credentialMessage: String?
    @State private var credentialError: String?
    @State private var byokConnect = BYOKConnectService()
    @State private var modelSelectorPresented = false

    var body: some View {
        Form {
            modelSection
            connectionSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("OpenRouter")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            settings = store.state.settings
            refreshCredentialState()
        }
        .onChange(of: settings) { _, new in store.updateSettings(new) }
        .sheet(isPresented: $modelSelectorPresented) {
            NavigationStack {
                OpenRouterModelSelectorView(selectedModelID: modelBinding)
            }
            .presentationDragIndicator(.visible)
        }
        .animation(.default, value: credentialMessage)
        .animation(.default, value: credentialError)
    }

    // MARK: - Binding

    private var modelBinding: Binding<String> {
        Binding(
            get: { store.state.settings.llmModel },
            set: { newValue in
                var updated = store.state.settings
                updated.llmModel = newValue
                store.updateSettings(updated)
            }
        )
    }

    // MARK: - Model section

    private var modelSection: some View {
        Section {
            Button {
                modelSelectorPresented = true
            } label: {
                HStack(spacing: 12) {
                    ProviderLogoView(
                        providerID: providerIDFromModel(store.state.settings.llmModel),
                        providerName: providerNameFromModel(store.state.settings.llmModel),
                        size: 34
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.state.settings.llmModel)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("Active model")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        } header: {
            Text("Model")
        } footer: {
            Text("The language model your agent uses for every request.")
        }
    }

    // MARK: - Connection section

    private var connectionSection: some View {
        Section {
            // Status row
            Label(statusTitle, systemImage: statusIcon)
                .foregroundStyle(statusColor)

            // BYOK button
            Button {
                Task { await connectWithBYOK() }
            } label: {
                HStack {
                    Label(
                        isConnectingBYOK ? "Connecting..." : byokButtonTitle,
                        systemImage: "key.viewfinder"
                    )
                    if isConnectingBYOK {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .buttonStyle(.glassProminent)
            .disabled(isConnectingBYOK)

            // Manual key field
            HStack {
                if showManualAPIKey {
                    TextField("sk-or-v1-…", text: $manualAPIKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField("Paste OpenRouter API key", text: $manualAPIKey)
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

            // Save manual key
            Button {
                saveManualKey()
            } label: {
                Label("Save Manual Key", systemImage: "square.and.arrow.down")
            }
            .disabled(manualAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            // Disconnect (only when key stored)
            if hasStoredOpenRouterKey {
                Button(role: .destructive) {
                    disconnectOpenRouter()
                } label: {
                    Label("Disconnect", systemImage: "trash")
                }
            }

            // Flash messages
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
            Text("BYOK opens byok.f7z.io for consent and stores the returned key in Keychain. Manual keys are also saved only in Keychain.")
        }
    }

    // MARK: - Status helpers

    private var statusTitle: String {
        guard hasStoredOpenRouterKey else {
            return settings.openRouterCredentialSource == .none ? "Not connected" : "Reconnect required"
        }
        switch settings.openRouterCredentialSource {
        case .byok:   return "Connected with BYOK"
        case .manual: return "Manual key saved"
        case .none:   return "Key stored"
        }
    }

    private var statusIcon: String {
        hasStoredOpenRouterKey ? "checkmark.seal.fill" : "xmark.seal"
    }

    private var statusColor: Color {
        hasStoredOpenRouterKey ? .green : .secondary
    }

    private var byokButtonTitle: String {
        settings.openRouterCredentialSource == .byok ? "Reconnect BYOK" : "Connect with BYOK"
    }

    // MARK: - Model ID helpers

    private func providerIDFromModel(_ modelID: String) -> String {
        modelID.split(separator: "/", maxSplits: 1).first.map(String.init) ?? "openrouter"
    }

    private func providerNameFromModel(_ modelID: String) -> String {
        providerIDFromModel(modelID)
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    // MARK: - Credential actions

    private func connectWithBYOK() async {
        settings = store.state.settings
        credentialError = nil
        credentialMessage = nil
        isConnectingBYOK = true
        defer { isConnectingBYOK = false }

        do {
            let token = try await byokConnect.connectOpenRouter()
            try OpenRouterCredentialStore.saveAPIKey(token.apiKey)
            settings.markOpenRouterBYOK(keyID: token.keyID, keyLabel: token.keyLabel)
            store.updateSettings(settings)
            manualAPIKey = ""
            refreshCredentialState()
            credentialMessage = "OpenRouter connected with BYOK."
            Haptics.success()
        } catch {
            credentialError = error.localizedDescription
        }
    }

    private func saveManualKey() {
        settings = store.state.settings
        credentialError = nil
        credentialMessage = nil
        do {
            try OpenRouterCredentialStore.saveAPIKey(manualAPIKey)
            settings.markOpenRouterManual()
            store.updateSettings(settings)
            manualAPIKey = ""
            refreshCredentialState()
            credentialMessage = "OpenRouter key saved in Keychain."
            Haptics.success()
        } catch {
            credentialError = "OpenRouter key could not be saved."
        }
    }

    private func disconnectOpenRouter() {
        settings = store.state.settings
        credentialError = nil
        credentialMessage = nil
        do {
            try OpenRouterCredentialStore.deleteAPIKey()
            settings.clearOpenRouterCredential()
            store.updateSettings(settings)
            manualAPIKey = ""
            refreshCredentialState()
            credentialMessage = "OpenRouter disconnected."
            Haptics.success()
        } catch {
            credentialError = "OpenRouter key could not be deleted."
        }
    }

    private func refreshCredentialState() {
        hasStoredOpenRouterKey = OpenRouterCredentialStore.hasAPIKey()
    }
}
