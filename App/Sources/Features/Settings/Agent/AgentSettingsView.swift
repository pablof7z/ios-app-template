import SwiftUI

struct AgentSettingsView: View {
    @Environment(AppStateStore.self) private var store
    @State private var settings: Settings = Settings()
    @State private var hasOpenRouterKey: Bool = false
    @State private var hasNostrKey: Bool = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            List {
                setupSection
                agentSection
                nostrSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Agent")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            settings = store.state.settings
            hasOpenRouterKey = OpenRouterCredentialStore.hasAPIKey()
            hasNostrKey = NostrCredentialStore.hasPrivateKey()
        }
        .onChange(of: settings) { _, new in
            store.updateSettings(new)
        }
        .onChange(of: settings.nostrEnabled) { Haptics.selection() }
    }

    // MARK: - Sections

    private var setupSection: some View {
        Section {
            AgentSetupStatusCard(
                hasOpenRouterKey: hasOpenRouterKey,
                hasNostrKey: hasNostrKey,
                nostrEnabled: settings.nostrEnabled
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

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
        Section {
            Toggle("Enabled", isOn: $settings.nostrEnabled)
                .disabled(!hasNostrKey)

            if !hasNostrKey {
                NavigationLink {
                    AgentIdentityView()
                } label: {
                    Label("Set up identity first", systemImage: "person.crop.circle.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
        } header: {
            Text("Nostr")
        } footer: {
            if hasNostrKey {
                Text("When enabled, this agent can receive and respond to messages over the Nostr network.")
            } else {
                Text("Generate a Nostr key pair in Identity before enabling this feature.")
            }
        }
    }

}
