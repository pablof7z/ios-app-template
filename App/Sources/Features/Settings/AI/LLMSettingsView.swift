import SwiftUI

struct LLMSettingsView: View {
    @Environment(AppStateStore.self) private var store
    @State private var agentSelectorPresented = false
    @State private var memorySelectorPresented = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            List {
                modelsSection
                connectionSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Language Models")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $agentSelectorPresented) {
            NavigationStack {
                OpenRouterModelSelectorView(selectedModelID: agentModelBinding)
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $memorySelectorPresented) {
            NavigationStack {
                OpenRouterModelSelectorView(selectedModelID: memoryModelBinding)
            }
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Sections

    private var modelsSection: some View {
        Section {
            modelRow(
                icon: "brain.head.profile",
                tint: .orange,
                role: "Agent",
                modelID: store.state.settings.llmModel
            ) {
                agentSelectorPresented = true
            }

            modelRow(
                icon: "memories",
                tint: .purple,
                role: "Memory Compilation",
                modelID: store.state.settings.memoryCompilationModel
            ) {
                memorySelectorPresented = true
            }
        } header: {
            Text("Model Roles")
        } footer: {
            Text("Each role can use a different model. Agent runs during conversations; Memory Compilation summarises and organises memories.")
        }
    }

    private var connectionSection: some View {
        Section("OpenRouter") {
            NavigationLink {
                OpenRouterSettingsView()
            } label: {
                SettingsRow(
                    icon: "key.viewfinder",
                    tint: .indigo,
                    title: "Connection",
                    value: connectionStatus
                )
            }
        }
    }

    // MARK: - Row helper

    private func modelRow(icon: String, tint: Color, role: String, modelID: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            SettingsRow(
                icon: icon,
                tint: tint,
                title: role,
                subtitle: shortName(modelID)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(role), \(shortName(modelID))")
        .accessibilityHint("Opens model selector")
    }

    // MARK: - Bindings

    private var agentModelBinding: Binding<String> {
        Binding(
            get: { store.state.settings.llmModel },
            set: { v in var s = store.state.settings; s.llmModel = v; store.updateSettings(s) }
        )
    }

    private var memoryModelBinding: Binding<String> {
        Binding(
            get: { store.state.settings.memoryCompilationModel },
            set: { v in var s = store.state.settings; s.memoryCompilationModel = v; store.updateSettings(s) }
        )
    }

    // MARK: - Helpers

    private func shortName(_ modelID: String) -> String {
        let m = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { return "Not set" }
        if let idx = m.lastIndex(of: "/") { return String(m[m.index(after: idx)...]) }
        return m
    }

    private var connectionStatus: String {
        switch store.state.settings.openRouterCredentialSource {
        case .byok:   return "BYOK"
        case .manual: return "Manual"
        case .none:   return "Not set up"
        }
    }
}
