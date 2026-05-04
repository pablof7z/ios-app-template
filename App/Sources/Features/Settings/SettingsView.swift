import SwiftUI

struct SettingsView: View {
    @Environment(AppStateStore.self) private var store
    @State private var settings: Settings = Settings()
    @State private var showManualAPIKey = false
    @State private var manualAPIKey = ""
    @State private var hasStoredOpenRouterKey = false
    @State private var isConnectingBYOK = false
    @State private var credentialMessage: String?
    @State private var credentialError: String?
    @State private var byokConnect = BYOKConnectService()
    @State private var showClearConfirm = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Model") {
                    TextField("openai/gpt-4o-mini", text: $settings.llmModel)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.callout.monospaced())
                }

                LabeledContent("OpenRouter") {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(openRouterStatusTitle)
                            .font(.callout)
                        if let subtitle = openRouterStatusSubtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    Task { await connectWithBYOK() }
                } label: {
                    Label(isConnectingBYOK ? "Connecting..." : byokButtonTitle, systemImage: "key.viewfinder")
                }
                .disabled(isConnectingBYOK)

                HStack {
                    if showManualAPIKey {
                        TextField("sk-or-v1-…", text: $manualAPIKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("Paste OpenRouter API Key", text: $manualAPIKey)
                    }
                    Button {
                        showManualAPIKey.toggle()
                    } label: {
                        Image(systemName: showManualAPIKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    saveManualKey()
                } label: {
                    Label("Save Manual Key", systemImage: "square.and.arrow.down")
                }
                .disabled(manualAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if hasStoredOpenRouterKey {
                    Button(role: .destructive) {
                        disconnectOpenRouter()
                    } label: {
                        Label("Disconnect OpenRouter", systemImage: "trash")
                    }
                }

                if let credentialMessage {
                    Text(credentialMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let credentialError {
                    Text(credentialError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Stepper("Max turns: \(settings.agentMaxTurns)", value: $settings.agentMaxTurns, in: 1...20)
            } header: {
                Text("AI Agent")
            } footer: {
                Text("BYOK opens byok.f7z.io for consent and stores the returned OpenRouter key in Keychain. Manual keys are also saved only in Keychain.")
            }

            Section("Agent Memory") {
                NavigationLink {
                    AgentMemoriesView()
                } label: {
                    HStack {
                        Label("Memories", systemImage: "brain")
                        Spacer()
                        if !store.activeMemories.isEmpty {
                            StatBadge.memories(store.activeMemories.count)
                        }
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–")
            }

            Section {
                Button("Clear All Data", role: .destructive) {
                    showClearConfirm = true
                }
            } footer: {
                Text("Permanently deletes all items, notes, friends, and memories. API credentials are preserved.")
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            settings = store.state.settings
            refreshCredentialState()
        }
        .onChange(of: settings) { _, new in store.updateSettings(new) }
        .alert("Clear All Data?", isPresented: $showClearConfirm) {
            Button("Clear Everything", role: .destructive) {
                store.clearAllData()
                Haptics.success()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all items, notes, friends, and memories. API credentials are preserved.")
        }
    }

    private var byokButtonTitle: String {
        settings.openRouterCredentialSource == .byok ? "Reconnect BYOK" : "Connect with BYOK"
    }

    private var openRouterStatusTitle: String {
        guard hasStoredOpenRouterKey else {
            return settings.openRouterCredentialSource == .none ? "Not connected" : "Reconnect required"
        }

        switch settings.openRouterCredentialSource {
        case .byok:
            return "Connected with BYOK"
        case .manual:
            return "Manual key saved"
        case .none:
            return "Key stored"
        }
    }

    private var openRouterStatusSubtitle: String? {
        if hasStoredOpenRouterKey, settings.openRouterCredentialSource == .byok {
            return settings.openRouterBYOKKeyLabel?.isEmpty == false ? settings.openRouterBYOKKeyLabel : "OpenRouter"
        }
        if !hasStoredOpenRouterKey, settings.openRouterCredentialSource != .none {
            return "The saved connection metadata exists, but the Keychain item is missing."
        }
        return nil
    }

    private func connectWithBYOK() async {
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
        } catch {
            credentialError = error.localizedDescription
        }
    }

    private func saveManualKey() {
        credentialError = nil
        credentialMessage = nil

        do {
            try OpenRouterCredentialStore.saveAPIKey(manualAPIKey)
            settings.markOpenRouterManual()
            store.updateSettings(settings)
            manualAPIKey = ""
            refreshCredentialState()
            credentialMessage = "OpenRouter key saved in Keychain."
        } catch {
            credentialError = "OpenRouter key could not be saved."
        }
    }

    private func disconnectOpenRouter() {
        credentialError = nil
        credentialMessage = nil

        do {
            try OpenRouterCredentialStore.deleteAPIKey()
            settings.clearOpenRouterCredential()
            store.updateSettings(settings)
            manualAPIKey = ""
            refreshCredentialState()
            credentialMessage = "OpenRouter disconnected."
        } catch {
            credentialError = "OpenRouter key could not be deleted."
        }
    }

    private func refreshCredentialState() {
        hasStoredOpenRouterKey = OpenRouterCredentialStore.hasAPIKey()
    }
}
