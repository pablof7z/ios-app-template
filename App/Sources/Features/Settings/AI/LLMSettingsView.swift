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
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tint)
                        .frame(width: 29, height: 29)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(role)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(shortName(modelID))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
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
