import SwiftUI

struct AISettingsView: View {
    @Environment(AppStateStore.self) private var store

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            List {
                defaultModelSection
                configurationSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("AI")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var defaultModelSection: some View {
        Section {
            NavigationLink {
                ProvidersSettingsView()
            } label: {
                HStack(spacing: 12) {
                    ProviderLetterTile(providerSlug: providerSlug)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active model")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(modelName)
                            .font(.body)
                        Text(store.state.settings.llmModel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Default Model")
        } footer: {
            Text("The model that powers your agent.")
        }
    }

    private var configurationSection: some View {
        Section("Configuration") {
            NavigationLink {
                ProvidersSettingsView()
            } label: {
                SettingsRow(
                    icon: "square.stack.3d.up",
                    tint: .indigo,
                    title: "Providers"
                )
            }
        }
    }

    // MARK: - Derived values

    private var modelFull: String {
        store.state.settings.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var providerSlug: String {
        guard !modelFull.isEmpty, let slashIdx = modelFull.firstIndex(of: "/") else {
            return modelFull.isEmpty ? "?" : String(modelFull.prefix(1))
        }
        return String(modelFull[..<slashIdx])
    }

    private var modelName: String {
        guard !modelFull.isEmpty else { return "Not set" }
        if let slashIdx = modelFull.lastIndex(of: "/") {
            return String(modelFull[modelFull.index(after: slashIdx)...])
        }
        return modelFull
    }
}

// MARK: - ProviderLetterTile

/// 44x44 circle showing the first letter of a provider slug.
private struct ProviderLetterTile: View {
    let providerSlug: String

    var body: some View {
        ZStack {
            Circle()
                .fill(tileColor)
                .frame(width: 44, height: 44)
            Text(letter)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var letter: String {
        String(providerSlug.prefix(1)).uppercased()
    }

    private var tileColor: Color {
        let hue = Double(abs(providerSlug.hashValue) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.75)
    }
}
