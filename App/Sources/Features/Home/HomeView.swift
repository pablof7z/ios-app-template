import SwiftUI

struct HomeView: View {
    @Environment(AppStateStore.self) private var store
    @State private var showAddItem = false
    @State private var showAgentCompose = false
    @State private var agentSession: AgentSession?
    @Namespace private var glassNamespace

    private var activeItems: [Item] {
        store.activeItems.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                if activeItems.isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "checkmark.circle",
                        description: Text("Add your first item or ask the agent.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(activeItems) { item in
                        ItemRow(item: item)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Spacing so list content scrolls above the FAB
                Color.clear.frame(height: 80)
            }

            // Agent status glass banner — floats above list when agent is running
            VStack(spacing: 0) {
                if let session = agentSession {
                    agentBanner(session: session)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.sm)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Glass FAB row
                GlassEffectContainer(spacing: AppTheme.Spacing.md) {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Button {
                            showAgentCompose = true
                        } label: {
                            Label("Ask Agent", systemImage: "sparkles")
                                .padding(.horizontal, AppTheme.Spacing.md)
                                .padding(.vertical, AppTheme.Spacing.sm)
                        }
                        .buttonStyle(.glass)
                        .glassEffectID("agent-btn", in: glassNamespace)

                        Button {
                            showAddItem = true
                        } label: {
                            Label("Add", systemImage: "plus")
                                .padding(.horizontal, AppTheme.Spacing.md)
                                .padding(.vertical, AppTheme.Spacing.sm)
                        }
                        .buttonStyle(.glassProminent)
                        .glassEffectID("add-btn", in: glassNamespace)
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.bottom, AppTheme.Spacing.md)
                }
            }
        }
        .navigationTitle("Home")
        .animation(.spring(duration: 0.35), value: agentSession?.phase.isActive)
        .sheet(isPresented: $showAddItem) {
            AddItemSheet(isPresented: $showAddItem)
        }
        .sheet(isPresented: $showAgentCompose) {
            AgentComposeSheet(
                isPresented: $showAgentCompose,
                agentSession: $agentSession
            )
        }
    }

    @ViewBuilder
    private func agentBanner(session: AgentSession) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            switch session.phase {
            case .running(let turn):
                ProgressView()
                    .tint(.blue)
                Text("Agent working · turn \(turn + 1)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            case .completed(let exhausted):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(exhausted ? "Agent done (turn limit)" : "Agent finished")
                    .font(.caption.weight(.medium))
                Spacer()
                Button("Dismiss") { withAnimation { agentSession = nil } }
                    .font(.caption)
                    .buttonStyle(.glass)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Button("Dismiss") { withAnimation { agentSession = nil } }
                    .font(.caption)
                    .buttonStyle(.glass)
            case .idle:
                EmptyView()
            }
        }
        .padding(AppTheme.Spacing.sm)
        .glassSurface(
            cornerRadius: AppTheme.Corner.lg,
            tint: session.phase.bannerTint
        )
    }
}

// MARK: - ItemRow

struct ItemRow: View {
    @Environment(AppStateStore.self) private var store
    let item: Item

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Button {
                Haptics.selection()
                store.setItemStatus(item.id, status: item.status == .pending ? .done : .pending)
            } label: {
                Image(systemName: item.status == .done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.status == .done ? .green : .secondary)
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.status == .done)
                    .foregroundStyle(item.status == .done ? .secondary : .primary)

                if let name = item.requestedByDisplayName {
                    Label(name, systemImage: "person.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.source == .agent {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.deleteItem(item.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                store.setItemStatus(item.id, status: item.status == .done ? .pending : .done)
                Haptics.selection()
            } label: {
                Label(
                    item.status == .done ? "Reopen" : "Done",
                    systemImage: item.status == .done ? "arrow.uturn.left" : "checkmark"
                )
            }
            .tint(.green)
        }
    }
}

// MARK: - AddItemSheet

private struct AddItemSheet: View {
    @Environment(AppStateStore.self) private var store
    @Binding var isPresented: Bool
    @State private var title = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What do you want to do?", text: $title, axis: .vertical)
                        .focused($focused)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }

    private func add() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addItem(title: trimmed)
        Haptics.success()
        isPresented = false
    }
}

// MARK: - AgentComposeSheet

private struct AgentComposeSheet: View {
    @Environment(AppStateStore.self) private var store
    @Binding var isPresented: Bool
    @Binding var agentSession: AgentSession?
    @State private var input = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tell the agent what to do…", text: $input, axis: .vertical)
                        .focused($focused)
                        .lineLimit(3...8)
                }
                Section {
                    Text("The agent can create items, take notes, and remember things about you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Run") { runAgent() }
                        .fontWeight(.semibold)
                        .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }

    private func runAgent() {
        let transcript = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return }

        let session = AgentSession(store: store, maxTurns: store.state.settings.agentMaxTurns)
        agentSession = session
        isPresented = false

        Task {
            await session.run(transcript: transcript)
        }
    }
}

// MARK: - AgentSession.Phase helpers

private extension AgentSession.Phase {
    var isActive: Bool {
        switch self {
        case .idle: false
        default: true
        }
    }

    var bannerTint: Color {
        switch self {
        case .running: .blue
        case .completed: .green
        case .failed: .orange
        case .idle: .clear
        }
    }
}
