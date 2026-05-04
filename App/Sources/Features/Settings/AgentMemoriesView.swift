import SwiftUI

struct AgentMemoriesView: View {
    @Environment(AppStateStore.self) private var store
    @State private var searchText = ""
    @State private var showClearConfirm = false

    private var filteredMemories: [AgentMemory] {
        let all = store.activeMemories.sorted { $0.createdAt > $1.createdAt }
        if searchText.isEmpty { return all }
        return all.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            if filteredMemories.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No memories yet" : "No results",
                    systemImage: searchText.isEmpty ? "brain" : "magnifyingglass",
                    description: Text(
                        searchText.isEmpty
                            ? "The agent will remember things about you as you interact."
                            : "Try a different search term."
                    )
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredMemories) { memory in
                    MemoryRow(memory: memory)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.deleteAgentMemory(memory.id)
                                Haptics.selection()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle("Memories")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search memories")
        .toolbar {
            if !store.activeMemories.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear All", role: .destructive) {
                        showClearConfirm = true
                    }
                }
            }
        }
        .alert("Clear All Memories?", isPresented: $showClearConfirm) {
            Button("Clear All", role: .destructive) {
                store.activeMemories.forEach { store.deleteAgentMemory($0.id) }
                Haptics.success()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The agent will lose everything it has learned about you. This cannot be undone.")
        }
    }
}

// MARK: - MemoryRow

private struct MemoryRow: View {
    let memory: AgentMemory

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(alignment: .top) {
                Image(systemName: "brain")
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .padding(.top, 2)

                Text(memory.content)
                    .font(AppTheme.Typography.callout)
                    .lineLimit(5)
            }

            Text(memory.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(AppTheme.Typography.mono)
                .foregroundStyle(.tertiary)
                .padding(.leading, 18)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }
}
