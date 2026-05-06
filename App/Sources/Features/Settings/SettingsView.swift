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
                destructiveSection
                versionFooterSection
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

            NavigationLink {
                NotificationSettingsView()
            } label: {
                SettingsRow(
                    icon: "bell.badge",
                    tint: .red,
                    title: "Notifications",
                    value: itemsWithReminders > 0 ? "\(itemsWithReminders) scheduled" : nil
                )
            }
        }
    }

    private var dataSection: some View {
        Section {
            NavigationLink {
                ProductivityStatsView()
            } label: {
                SettingsRow(
                    icon: "chart.bar.fill",
                    tint: .green,
                    title: "Productivity",
                    value: productivitySummary
                )
            }

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

    private var destructiveSection: some View {
        Section {
            Button("Clear All Data", role: .destructive) {
                showClearConfirm = true
            }
        } footer: {
            Text("Permanently deletes all items, notes, friends, and memories. API credentials and Nostr identity are preserved.")
        }
    }

    private var versionFooterSection: some View {
        Section {
        } footer: {
            Text(appVersionFooter)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Derived values

    private var productivitySummary: String {
        let done = store.state.items.filter { !$0.deleted && $0.status == .done }.count
        return done == 0 ? "No completions yet" : "\(done) completed"
    }

    private var itemsWithReminders: Int {
        store.state.items.filter { !$0.deleted && $0.status == .pending && $0.reminderAt != nil }.count
    }

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

    private var appVersionFooter: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "App Template  \(version)  (build \(build))"
    }
}
