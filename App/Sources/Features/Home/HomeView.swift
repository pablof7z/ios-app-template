import SwiftUI

// MARK: - Sort Order

private enum ItemSort: String, CaseIterable, Identifiable {
    case dateAddedDesc = "dateAddedDesc"
    case dateAddedAsc  = "dateAddedAsc"
    case titleAZ       = "titleAZ"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dateAddedDesc: return "Newest First"
        case .dateAddedAsc:  return "Oldest First"
        case .titleAZ:       return "Title A–Z"
        }
    }

    var systemImage: String {
        switch self {
        case .dateAddedDesc: return "arrow.down.circle"
        case .dateAddedAsc:  return "arrow.up.circle"
        case .titleAZ:       return "textformat.abc"
        }
    }
}

struct HomeView: View {
    @Environment(AppStateStore.self) private var store
    @Binding var pendingNewItemTitle: String?

    @State private var showCompose = false
    @State private var composeInitialTitle: String = ""
    @State private var completedExpanded: Bool = false
    @State private var editingItem: Item?
    @State private var searchText: String = ""
    @AppStorage("home.itemSort") private var sortOrder: String = ItemSort.dateAddedDesc.rawValue

    private var currentSort: ItemSort {
        ItemSort(rawValue: sortOrder) ?? .dateAddedDesc
    }

    private var isSearching: Bool { !searchText.isEmpty }

    private var sortedActiveItems: [Item] {
        switch currentSort {
        case .dateAddedDesc:
            return store.activeItems.sorted { $0.createdAt > $1.createdAt }
        case .dateAddedAsc:
            return store.activeItems.sorted { $0.createdAt < $1.createdAt }
        case .titleAZ:
            return store.activeItems.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
    }

    private var filteredActiveItems: [Item] {
        guard isSearching else { return sortedActiveItems }
        return sortedActiveItems.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var hasAnyItems: Bool {
        !store.activeItems.isEmpty || !store.completedItems.isEmpty
    }

    var body: some View {
        Group {
            if !hasAnyItems {
                emptyState
            } else {
                itemList
            }
        }
        .navigationTitle("Home")
        .searchable(text: $searchText, prompt: "Search items")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    composeInitialTitle = ""
                    showCompose = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityLabel("Add Item")
            }
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Sort by", selection: $sortOrder) {
                        ForEach(ItemSort.allCases) { sort in
                            Label(sort.label, systemImage: sort.systemImage)
                                .tag(sort.rawValue)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .accessibilityLabel("Sort Items")
                }
            }
        }
        .sheet(isPresented: $showCompose) {
            ItemComposeSheet(initialTitle: composeInitialTitle)
        }
        .sheet(item: $editingItem) { item in
            ItemEditSheet(item: item)
        }
        .onAppear { consumePendingTitle() }
        .onChange(of: pendingNewItemTitle) { consumePendingTitle() }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "checkmark.circle.dashed")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(.tertiary)
            VStack(spacing: AppTheme.Spacing.xs) {
                Text("Nothing to do")
                    .font(AppTheme.Typography.title)
                Text("Tap + to add your first item.")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Item List

    private var itemList: some View {
        List {
            if isSearching && filteredActiveItems.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowSeparator(.hidden)
            } else {
                activeItemsSection
            }
            if !isSearching && !store.completedItems.isEmpty {
                CompletedItemsSection(isExpanded: $completedExpanded)
            }
        }
        .listStyle(.plain)
        .animation(AppTheme.Animation.spring, value: filteredActiveItems.count)
        .animation(AppTheme.Animation.spring, value: store.completedItems.isEmpty)
    }

    @ViewBuilder
    private var activeItemsSection: some View {
        Section {
            ForEach(filteredActiveItems) { item in
                Button {
                    Haptics.selection()
                    editingItem = item
                } label: {
                    ItemRow(item: item)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityHint("Double-tap to edit")
                .listRowInsets(EdgeInsets(
                    top: AppTheme.Spacing.xs,
                    leading: AppTheme.Spacing.md,
                    bottom: AppTheme.Spacing.xs,
                    trailing: AppTheme.Spacing.md
                ))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        store.setItemStatus(item.id, status: .done)
                        Haptics.success()
                    } label: {
                        Label("Done", systemImage: "checkmark.circle.fill")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.deleteItem(item.id)
                        Haptics.medium()
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                }
            }
        }
    }

    // MARK: - Deep-Link

    private func consumePendingTitle() {
        guard let title = pendingNewItemTitle else { return }
        pendingNewItemTitle = nil
        composeInitialTitle = title
        showCompose = true
    }
}

// MARK: - Item Row

private struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(item.title)
                    .font(AppTheme.Typography.body)
                    .lineLimit(2)
                if let reminder = item.reminderAt {
                    let rel = ReminderLabel.from(reminder)
                    Label(rel.text, systemImage: "bell.fill")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(rel.color)
                }
            }
            Spacer(minLength: 0)
            sourceIcon
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var sourceIcon: some View {
        switch item.source {
        case .agent:
            Image(systemName: "sparkle")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        case .voice:
            Image(systemName: "mic.fill")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        case .manual:
            EmptyView()
        }
    }
}

// MARK: - ReminderLabel

private struct ReminderLabel {
    let text: String
    let color: Color

    static func from(_ date: Date) -> ReminderLabel {
        let cal = Calendar.current
        let now = Date()
        let timeStr = date.formatted(date: .omitted, time: .shortened)

        if date < now {
            // Overdue
            if cal.isDateInToday(date) {
                return ReminderLabel(text: "Today, \(timeStr)", color: .red)
            } else if cal.isDateInYesterday(date) {
                return ReminderLabel(text: "Yesterday, \(timeStr)", color: .red)
            } else {
                return ReminderLabel(text: "Overdue · \(date.formatted(date: .abbreviated, time: .shortened))", color: .red)
            }
        } else if cal.isDateInToday(date) {
            return ReminderLabel(text: "Today, \(timeStr)", color: .orange)
        } else if cal.isDateInTomorrow(date) {
            return ReminderLabel(text: "Tomorrow, \(timeStr)", color: .orange)
        } else if let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day,
                  days <= 6 {
            let weekday = date.formatted(.dateTime.weekday(.wide))
            return ReminderLabel(text: "\(weekday), \(timeStr)", color: .secondary)
        } else {
            return ReminderLabel(text: date.formatted(date: .abbreviated, time: .shortened), color: .secondary)
        }
    }
}
