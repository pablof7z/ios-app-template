import SwiftUI

struct AISettingsView: View {
    @Environment(AppStateStore.self) private var store

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            List {
                llmSection
                audioSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("AI")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var llmSection: some View {
        Section("LLM") {
            NavigationLink {
                LLMSettingsView()
            } label: {
                SettingsRow(
                    icon: "cpu",
                    tint: .purple,
                    title: "Language Models",
                    subtitle: agentModelShortName,
                    value: openRouterStatus
                )
            }
        }
    }

    private var audioSection: some View {
        Section("Audio") {
            NavigationLink {
                ElevenLabsSettingsView()
            } label: {
                SettingsRow(
                    icon: "waveform",
                    tint: .teal,
                    title: "ElevenLabs",
                    value: elevenLabsStatus
                )
            }
        }
    }

    private var settings: Settings { store.state.settings }

    private var agentModelShortName: String? {
        let model = settings.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { return nil }
        if let idx = model.lastIndex(of: "/") { return String(model[model.index(after: idx)...]) }
        return model
    }

    private var openRouterStatus: String {
        switch settings.openRouterCredentialSource {
        case .byok:   return "BYOK"
        case .manual: return "Manual"
        case .none:   return "Not set up"
        }
    }

    private var elevenLabsStatus: String {
        switch settings.elevenLabsCredentialSource {
        case .byok:   return "BYOK"
        case .manual: return "Manual"
        case .none:   return "Not set up"
        }
    }
}
