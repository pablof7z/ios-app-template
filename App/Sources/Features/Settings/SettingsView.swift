import SwiftUI

struct SettingsView: View {
    @Environment(AppStateStore.self) private var store
    @State private var showClearConfirm = false
    @State private var hasStoredKey = false
    @State private var pendingCount = 0

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    AgentHubView()
                } label: {
                    HStack {
                        Label("Agent", systemImage: "brain.head.profile")
                        Spacer()
                        agentStatusBadge
                    }
                }
            } header: {
                Text("Configuration")
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
                Text("Permanently deletes all items, notes, friends, and memories. API credentials and Nostr identity are preserved.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            hasStoredKey = OpenRouterCredentialStore.hasAPIKey()
            pendingCount = store.pendingNostrApprovals.count
        }
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

    @ViewBuilder
    private var agentStatusBadge: some View {
        HStack(spacing: 6) {
            if pendingCount > 0 {
                StatBadge(value: pendingCount, label: nil, color: .orange)
            }
            Text(hasStoredKey ? "Connected" : "Not set up")
                .font(.caption)
                .foregroundStyle(hasStoredKey ? .green : .secondary)
        }
    }
}
