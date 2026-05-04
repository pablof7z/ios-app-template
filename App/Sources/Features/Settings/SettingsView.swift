import SwiftUI

struct SettingsView: View {
    @Environment(AppStateStore.self) private var store
    @State private var settings: Settings = Settings()
    @State private var showAPIKey = false

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

                HStack {
                    if showAPIKey {
                        TextField("sk-or-v1-…", text: $settings.openRouterAPIKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("OpenRouter API Key", text: $settings.openRouterAPIKey)
                    }
                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Stepper("Max turns: \(settings.agentMaxTurns)", value: $settings.agentMaxTurns, in: 1...20)
            } header: {
                Text("AI Agent")
            } footer: {
                Text("Get an API key at openrouter.ai. The agent uses this to process your requests.")
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–")
            }

            Section {
                Button("Clear All Data", role: .destructive) {
                    // TODO: Implement data clear with confirmation
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear { settings = store.state.settings }
        .onChange(of: settings) { _, new in store.updateSettings(new) }
    }
}
