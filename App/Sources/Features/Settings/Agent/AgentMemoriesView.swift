import SwiftUI
import UIKit

// MARK: - Date bucket

/// Relative-date grouping for memory list sections.
private enum MemoryDateBucket: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case earlier = "Earlier"

    /// Assigns a memory to its bucket relative to `now`.
    static func bucket(for date: Date, now: Date, calendar: Calendar) -> MemoryDateBucket {
        if calendar.isDateInToday(date) { return .today }
        if calendar.isDateInYesterday(date) { return .yesterday }
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        if date >= weekAgo { return .thisWeek }
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
        if date >= monthAgo { return .thisMonth }
        return .earlier
    }
}

struct AgentMemoriesView: View {
    @Environment(AppStateStore.self) private var store
    @State private var searchText = ""
    @State private var showClearConfirm = false

    // MARK: - Derived data

    private var filteredMemories: [AgentMemory] {
        let all = store.activeMemories.sorted { $0.createdAt > $1.createdAt }
        if searchText.isEmpty { return all }
        return all.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    /// Memories grouped by relative-date bucket, preserving reverse-chron order within each group.
    private var groupedMemories: [(bucket: MemoryDateBucket, memories: [AgentMemory])] {
        let now = Date()
        let calendar = Calendar.current
        var dict: [MemoryDateBucket: [AgentMemory]] = [:]
        for memory in filteredMemories {
            let key = MemoryDateBucket.bucket(for: memory.createdAt, now: now, calendar: calendar)
            dict[key, default: []].append(memory)
        }
        return MemoryDateBucket.allCases.compactMap { bucket in
            guard let memories = dict[bucket], !memories.isEmpty else { return nil }
            return (bucket, memories)
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            if filteredMemories.isEmpty {
                emptyState
            } else {
                memorySections
            }
        }
        .navigationTitle("Memories")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search memories")
        .toolbar { toolbarContent }
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

    // MARK: - Subviews

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                searchText.isEmpty ? "No memories yet" : "No results",
                systemImage: searchText.isEmpty ? "brain" : "magnifyingglass"
            )
            .symbolEffect(.pulse, isActive: searchText.isEmpty && store.activeMemories.isEmpty)
        } description: {
            Text(
                searchText.isEmpty
                    ? "The agent will remember things about you as you interact."
                    : "Try a different search term."
            )
        }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var memorySections: some View {
        ForEach(groupedMemories, id: \.bucket) { group in
            Section(group.bucket.rawValue) {
                ForEach(group.memories) { memory in
                    memoryRow(memory)
                }
            }
        }
    }

    private func memoryRow(_ memory: AgentMemory) -> some View {
        MemoryRow(memory: memory)
            .contextMenu {
                Button {
                    UIPasteboard.general.string = memory.content
                    Haptics.selection()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                Button(role: .destructive) {
                    store.deleteAgentMemory(memory.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    store.deleteAgentMemory(memory.id)
                    Haptics.selection()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !store.activeMemories.isEmpty {
            ToolbarItem(placement: .destructiveAction) {
                Button("Clear All", role: .destructive) {
                    showClearConfirm = true
                }
            }
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
