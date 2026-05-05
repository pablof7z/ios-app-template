import SwiftUI

struct AgentSettingsView: View {
    @Environment(AppStateStore.self) private var store
    @State private var settings: Settings = Settings()
    @State private var hasNostrKey: Bool = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            List {
                agentSection
                nostrSection
                runtimeSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Agent")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            settings = store.state.settings
            hasNostrKey = NostrCredentialStore.hasPrivateKey()
        }
        .onChange(of: settings) { _, new in
            store.updateSettings(new)
        }
    }

    // MARK: - Sections

    private var agentSection: some View {
        Section("Agent") {
            NavigationLink {
                AgentIdentityView()
            } label: {
                SettingsRow(
                    icon: "person.crop.circle",
                    tint: .pink,
                    title: "Identity"
                )
            }

            NavigationLink {
                AgentFriendsView()
            } label: {
                SettingsRow(
                    icon: "person.2.fill",
                    tint: .blue,
                    title: "Friends",
                    badge: store.state.friends.count
                )
            }

            NavigationLink {
                AgentWhitelistView()
            } label: {
                SettingsRow(
                    icon: "checkmark.shield.fill",
                    tint: .green,
                    title: "Whitelist",
                    badge: store.pendingNostrApprovals.count
                )
            }

            NavigationLink {
                AgentBlockedView()
            } label: {
                SettingsRow(
                    icon: "nosign",
                    tint: .red,
                    title: "Blocked",
                    badge: store.state.nostrBlockedPubkeys.count
                )
            }

            NavigationLink {
                AgentMemoriesView()
            } label: {
                SettingsRow(
                    icon: "brain",
                    tint: .purple,
                    title: "Memories",
                    badge: store.activeMemories.count
                )
            }
        }
    }

    private var nostrSection: some View {
        Section("Nostr") {
            Toggle("Enabled", isOn: $settings.nostrEnabled)
        }
    }

    private var runtimeSection: some View {
        Section("Runtime") {
            Stepper(
                "Max turns: \(settings.agentMaxTurns)",
                value: $settings.agentMaxTurns,
                in: 1...20
            )
        }
    }
}
