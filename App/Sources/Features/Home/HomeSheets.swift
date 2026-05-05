import SwiftUI

// MARK: - AddItemSheet

struct AddItemSheet: View {
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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
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
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        store.addItem(title: t)
        Haptics.success()
        isPresented = false
    }
}

// MARK: - AgentComposeSheet

struct AgentComposeSheet: View {
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
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
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
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let session = AgentSession(store: store, maxTurns: store.state.settings.agentMaxTurns)
        agentSession = session
        isPresented = false
        Task { await session.run(transcript: t) }
    }
}
