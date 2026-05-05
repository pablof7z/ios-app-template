import SwiftUI
import UIKit

struct HomeSearchView: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var onEditNote: (Note) -> Void
    var onToggleItem: (Item) -> Void

    @State private var query: String = ""

    var body: some View {
        NavigationStack {
            content
                .background(background.ignoresSafeArea())
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Items, notes, memories, friends"
                )
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var content: some View {
        if trimmedQuery.isEmpty {
            suggestions
        } else if !hasAnyResult {
            noResults
        } else {
            results
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Filtered data

    private var matchedItems: [Item] {
        guard !trimmedQuery.isEmpty else { return [] }
        return store.activeItems
            .filter { $0.title.localizedCaseInsensitiveContains(trimmedQuery) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var matchedNotes: [Note] {
        guard !trimmedQuery.isEmpty else { return [] }
        return store.activeNotes
            .filter { $0.text.localizedCaseInsensitiveContains(trimmedQuery) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var matchedMemories: [AgentMemory] {
        guard !trimmedQuery.isEmpty else { return [] }
        return store.activeMemories
            .filter { $0.content.localizedCaseInsensitiveContains(trimmedQuery) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var matchedFriends: [Friend] {
        guard !trimmedQuery.isEmpty else { return [] }
        return store.state.friends
            .filter {
                $0.displayName.localizedCaseInsensitiveContains(trimmedQuery)
                    || $0.identifier.localizedCaseInsensitiveContains(trimmedQuery)
            }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }

    private var hasAnyResult: Bool {
        !matchedItems.isEmpty
            || !matchedNotes.isEmpty
            || !matchedMemories.isEmpty
            || !matchedFriends.isEmpty
    }

    // MARK: - Result list

    private var results: some View {
        List {
            if !matchedItems.isEmpty {
                Section {
                    ForEach(matchedItems) { item in
                        Button {
                            Haptics.selection()
                            onToggleItem(item)
                            dismiss()
                        } label: {
                            ItemResultRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionHeader("Items", count: matchedItems.count, icon: "checkmark.circle")
                }
            }

            if !matchedNotes.isEmpty {
                Section {
                    ForEach(matchedNotes) { note in
                        Button {
                            Haptics.selection()
                            onEditNote(note)
                            dismiss()
                        } label: {
                            NoteResultRow(note: note, query: trimmedQuery)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionHeader("Notes", count: matchedNotes.count, icon: "note.text")
                }
            }

            if !matchedMemories.isEmpty {
                Section {
                    ForEach(matchedMemories) { memory in
                        Button {
                            UIPasteboard.general.string = memory.content
                            Haptics.selection()
                        } label: {
                            MemoryResultRow(memory: memory)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionHeader("Memories", count: matchedMemories.count, icon: "brain")
                }
            }

            if !matchedFriends.isEmpty {
                Section {
                    ForEach(matchedFriends) { friend in
                        NavigationLink {
                            FriendDetailView(friend: friend)
                        } label: {
                            FriendResultRow(friend: friend)
                        }
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionHeader("Friends", count: matchedFriends.count, icon: "person.2.fill")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .transition(.opacity)
        .animation(AppTheme.Animation.springFast, value: matchedItems.count)
        .animation(AppTheme.Animation.springFast, value: matchedNotes.count)
        .animation(AppTheme.Animation.springFast, value: matchedMemories.count)
        .animation(AppTheme.Animation.springFast, value: matchedFriends.count)
    }

    private func sectionHeader(_ title: String, count: Int, icon: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(AppTheme.Typography.caption)
                .textCase(.uppercase)
                .tracking(0.6)
            Text("\(count)")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 1)
                .glassEffect(.regular, in: .capsule)
            Spacer()
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - States

    private var noResults: some View {
        ContentUnavailableView {
            Label("No results", systemImage: "magnifyingglass")
        } description: {
            Text("No matches for \u{201C}\(trimmedQuery)\u{201D}.")
        }
        .transition(.opacity)
    }

    private var suggestions: some View {
        let categories: [(String, String, String, Color)] = [
            ("Items", "\(store.activeItems.count) active", "checkmark.circle", .green),
            ("Notes", "\(store.activeNotes.count) saved", "note.text", .yellow),
            ("Memories", "\(store.activeMemories.count) recorded", "brain", .purple),
            ("Friends", "\(store.state.friends.count) trusted", "person.2.fill", .indigo)
        ]
        return ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Search across")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .padding(.horizontal, AppTheme.Spacing.xs)

                GlassEffectContainer(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(categories.enumerated()), id: \.offset) { idx, c in
                            suggestionRow(title: c.0, subtitle: c.1, icon: c.2, tint: c.3)
                            if idx < categories.count - 1 {
                                Divider().padding(.leading, 56).opacity(0.4)
                            }
                        }
                    }
                    .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
                }

                Text("Tip: type any keyword to filter across every section instantly.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, AppTheme.Spacing.xs)
                    .padding(.top, AppTheme.Spacing.sm)
            }
            .padding(AppTheme.Spacing.md)
        }
        .transition(.opacity)
    }

    private func suggestionRow(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle().fill(tint.opacity(0.18)).frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppTheme.Typography.headline)
                Text(subtitle).font(AppTheme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.indigo.opacity(0.05),
                Color.blue.opacity(0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Result rows

private struct ItemResultRow: View {
    let item: Item
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: item.status == .done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(item.status == .done ? AnyShapeStyle(Color.green) : AnyShapeStyle(.secondary))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title.isEmpty ? "Untitled" : item.title)
                    .font(AppTheme.Typography.body)
                    .strikethrough(item.status == .done, color: .secondary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                Text(relativeDate(item.createdAt))
                    .font(AppTheme.Typography.caption2).foregroundStyle(.tertiary).monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

private struct NoteResultRow: View {
    let note: Note
    let query: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snippet)
                .font(AppTheme.Typography.body)
                .lineLimit(3).multilineTextAlignment(.leading)
            Text(relativeDate(note.createdAt))
                .font(AppTheme.Typography.caption2).foregroundStyle(.tertiary).monospacedDigit()
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var snippet: String {
        let trimmed = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Untitled" }
        guard let range = trimmed.range(of: query, options: .caseInsensitive) else { return trimmed }
        let lower = trimmed.distance(from: trimmed.startIndex, to: range.lowerBound)
        guard lower > 32 else { return trimmed }
        let start = trimmed.index(range.lowerBound, offsetBy: -32)
        return "\u{2026}" + String(trimmed[start...])
    }
}

private struct MemoryResultRow: View {
    let memory: AgentMemory
    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: "brain").font(.caption).foregroundStyle(.purple).padding(.top, 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.content)
                    .font(AppTheme.Typography.callout)
                    .lineLimit(3).multilineTextAlignment(.leading)
                Text(relativeDate(memory.createdAt))
                    .font(AppTheme.Typography.caption2).foregroundStyle(.tertiary).monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FriendResultRow: View {
    let friend: Friend
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            FriendAvatar(friend: friend, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName).font(AppTheme.Typography.body)
                Text(friend.shortIdentifier)
                    .font(AppTheme.Typography.mono).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

private func relativeDate(_ date: Date) -> String {
    let interval = Date().timeIntervalSince(date)
    if interval < 60 { return "just now" }
    if interval < 3600 { return "\(Int(interval / 60))m" }
    if interval < 86_400 { return "\(Int(interval / 3600))h" }
    if interval < 604_800 { return "\(Int(interval / 86_400))d" }
    return date.formatted(date: .abbreviated, time: .omitted)
}
