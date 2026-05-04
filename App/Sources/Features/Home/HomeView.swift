import SwiftUI

struct HomeView: View {
    @Environment(AppStateStore.self) private var store
    @State private var showAddItem = false
    @State private var agentInput = ""
    @State private var showAgentCompose = false
    @State private var agentSession: AgentSession?

    private var activeItems: [Item] {
        store.activeItems.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if let session = agentSession {
                agentStatusRow(session: session)
            }

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
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Add Item") { showAddItem = true }
                    Button("Ask Agent") { showAgentCompose = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
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
    private func agentStatusRow(session: AgentSession) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            switch session.phase {
            case .running(let turn):
                ProgressView()
                Text("Agent working (turn \(turn + 1))…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .completed(let exhausted):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(exhausted ? "Agent finished (turn limit reached)" : "Agent done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Dismiss") { agentSession = nil }
                    .font(.caption)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Dismiss") { agentSession = nil }
                    .font(.caption)
            case .idle:
                EmptyView()
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
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
                Label(item.status == .done ? "Reopen" : "Done", systemImage: item.status == .done ? "arrow.uturn.left" : "checkmark")
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
