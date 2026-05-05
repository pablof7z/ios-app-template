import SwiftUI

// MARK: - DataExportView
//
// Settings → Data → Export. Generates a JSON document of the live `AppState`
// (items, notes, friends, agent memories, agent activity, non-secret settings)
// and surfaces it through a system share sheet so the user can save it to
// Files, AirDrop it, or send it through any share extension.
//
// Inspired by cut-tracker's `ExportCSVSheet` (sheet shape + share) and
// win-the-day-app's `FullBackupManager` (versioned JSON envelope).
//
// Secrets are never exported — see `DataExport.redactedState(from:)`.

struct DataExportView: View {
    @Environment(AppStateStore.self) private var store

    @State private var fileURL: URL?
    @State private var fileSize: Int?
    @State private var errorMessage: String?
    @State private var generatedAt: Date?
    @State private var showShareSheet = false
    @State private var showClearConfirmation = false
    @State private var exportCompletedOnly = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            List {
                summarySection
                actionSection
                dangerSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let fileURL {
                ShareSheet(items: [fileURL])
            }
        }
        .confirmationDialog(
            "Clear All Data",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Data", role: .destructive) {
                store.clearAllData()
                Haptics.success()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all items, notes, friends, memories, and agent activity. This action cannot be undone.")
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section("Contents") {
            statRow(icon: "checklist", tint: .blue, label: "Items", count: stats.items)
            statRow(icon: "note.text", tint: .indigo, label: "Notes", count: stats.notes)
            statRow(icon: "person.2.fill", tint: .green, label: "Friends", count: stats.friends)
            statRow(icon: "brain.head.profile", tint: .orange, label: "Memories", count: stats.memories)
            statRow(icon: "clock.arrow.circlepath", tint: .gray, label: "Agent activity", count: stats.agentActivity)
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        if let errorMessage {
            Section {
                Text(errorMessage)
                    .foregroundStyle(.red)
                Button("Try again") { generate() }
            }
        } else {
            Section {
                Toggle(isOn: $exportCompletedOnly) {
                    SettingsRow(
                        icon: "checkmark.circle.fill",
                        tint: .green,
                        title: "Completed items only",
                        subtitle: "Export only items marked as done"
                    )
                }
                Button {
                    generate()
                } label: {
                    SettingsRow(
                        icon: "square.and.arrow.up",
                        tint: .indigo,
                        title: "Export & Share",
                        subtitle: "Generates a JSON file and opens the share sheet"
                    )
                }
                .foregroundStyle(.primary)
            } footer: {
                Text(actionFooterText)
            }
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                SettingsRow(
                    icon: "trash.fill",
                    tint: .red,
                    title: "Clear All Data"
                )
            }
        } footer: {
            Text("Permanently deletes all items, notes, friends, memories, and agent activity.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            SettingsRow(
                icon: "doc.text",
                tint: .gray,
                title: "Format",
                value: "JSON"
            )
            SettingsRow(
                icon: "number",
                tint: .gray,
                title: "Schema",
                value: "v\(DataExport.currentSchemaVersion)"
            )
        }
    }

    // MARK: - Subviews

    private func statRow(icon: String, tint: Color, label: String, count: Int) -> some View {
        SettingsRow(
            icon: icon,
            tint: tint,
            title: label,
            value: "\(count)"
        )
    }

    // MARK: - Derived

    private var stats: DataExport.Stats {
        DataExport.stats(for: store.state)
    }

    private var actionFooterText: String {
        let records = stats.totalRecords
        let base = "\(records) record\(records == 1 ? "" : "s")"
        if let size = fileSize, let generatedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .medium
            return "\(base) · \(formatBytes(size)) · Last exported \(formatter.string(from: generatedAt))"
        }
        return "\(base) · Bundles items, notes, friends, agent memories, and agent activity. API keys and the Nostr private key are never included."
    }

    // MARK: - Actions

    private func generate() {
        do {
            let now = Date()
            var exportState = store.state
            if exportCompletedOnly {
                exportState.items = exportState.items.filter { $0.status == .done }
            }
            let url = try DataExport.writeExport(of: exportState, now: now)
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            fileURL = url
            fileSize = (attrs?[.size] as? NSNumber)?.intValue
            generatedAt = now
            errorMessage = nil
            Haptics.success()
            showShareSheet = true
        } catch {
            errorMessage = "Could not generate export: \(error.localizedDescription)"
            fileURL = nil
            fileSize = nil
            Haptics.error()
        }
    }

    private func formatBytes(_ n: Int) -> String {
        if n >= 1_048_576 { return String(format: "%.1f MB", Double(n) / 1_048_576) }
        if n >= 1024 { return String(format: "%.1f KB", Double(n) / 1024) }
        return "\(n) B"
    }
}
