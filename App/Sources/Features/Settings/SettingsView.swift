import SwiftUI

struct SettingsView: View {
    @Environment(AppStateStore.self) private var store
    @State private var showClearConfirm = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            List {
                configurationSection
                dataSection
                aboutSection
                destructiveSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
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

    // MARK: - Sections

    private var configurationSection: some View {
        Section("Configuration") {
            NavigationLink {
                AISettingsView()
            } label: {
                SettingsRow(
                    icon: "sparkles",
                    tint: .blue,
                    title: "AI",
                    value: currentModelShortName
                )
            }

            NavigationLink {
                AgentSettingsView()
            } label: {
                SettingsRow(
                    icon: "brain.head.profile",
                    tint: .orange,
                    title: "Agent",
                    badge: store.pendingNostrApprovals.count
                )
            }
        }
    }

    private var dataSection: some View {
        Section {
            NavigationLink {
                DataExportView()
            } label: {
                SettingsRow(
                    icon: "square.and.arrow.up",
                    tint: .indigo,
                    title: "Export Data",
                    value: exportSummary
                )
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Generates a portable JSON file of items, notes, friends, memories, and agent activity. Secrets are not included.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            SettingsRow(icon: "info.circle", tint: .gray, title: "Version", value: versionString)
            SettingsRow(icon: "hammer", tint: .gray, title: "Build", value: buildString)
        }
    }

    private var destructiveSection: some View {
        Section {
            Button("Clear All Data", role: .destructive) {
                showClearConfirm = true
            }
        } footer: {
            Text("Permanently deletes all items, notes, friends, and memories. API credentials and Nostr identity are preserved.")
        }
    }

    // MARK: - Derived values

    private var exportSummary: String {
        let total = DataExport.stats(for: store.state).totalRecords
        return "\(total) record\(total == 1 ? "" : "s")"
    }

    private var currentModelShortName: String {
        let model = store.state.settings.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { return "Not set" }
        if let slashIndex = model.lastIndex(of: "/") {
            return String(model[model.index(after: slashIndex)...])
        }
        return model
    }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var buildString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }
}
