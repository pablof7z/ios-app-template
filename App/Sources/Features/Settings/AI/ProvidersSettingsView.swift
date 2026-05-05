import SwiftUI

struct ProvidersSettingsView: View {
    @Environment(AppStateStore.self) private var store

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            List {
                providersSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Providers")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var providersSection: some View {
        Section {
            NavigationLink {
                OpenRouterSettingsView()
            } label: {
                SettingsRow(
                    icon: "cpu",
                    tint: .purple,
                    title: "OpenRouter",
                    subtitle: openRouterSubtitle,
                    value: openRouterStatusString
                )
            }

            NavigationLink {
                ElevenLabsSettingsView()
            } label: {
                SettingsRow(
                    icon: "waveform",
                    tint: .teal,
                    title: "ElevenLabs",
                    value: elevenLabsStatusString
                )
            }
        } header: {
            Text("AI Providers")
        } footer: {
            Text("OpenRouter routes language model calls. ElevenLabs handles speech and transcription.")
        }
    }

    // MARK: - Derived values

    private var settings: Settings { store.state.settings }

    private var openRouterStatusString: String {
        switch settings.openRouterCredentialSource {
        case .byok:   return "BYOK"
        case .manual: return "Manual"
        case .none:   return "Not set up"
        }
    }

    private var elevenLabsStatusString: String {
        switch settings.elevenLabsCredentialSource {
        case .byok:   return "BYOK"
        case .manual: return "Manual"
        case .none:   return "Not set up"
        }
    }

    private var openRouterSubtitle: String? {
        guard settings.openRouterCredentialSource != .none else { return nil }
        let model = settings.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { return nil }
        if let slashIdx = model.lastIndex(of: "/") {
            return String(model[model.index(after: slashIdx)...])
        }
        return model
    }
}

