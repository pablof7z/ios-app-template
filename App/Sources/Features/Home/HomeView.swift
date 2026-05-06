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

// MARK: - Source Filter

private enum SourceFilter: String, CaseIterable, Identifiable {
    case all    = "all"
    case manual = "manual"
    case agent  = "agent"
    case voice  = "voice"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:    return "All"
        case .manual: return "Manual"
        case .agent:  return "Agent"
        case .voice:  return "Voice"
        }
    }
}

// MARK: - AppStorage keys

private enum StorageKey {
    static let itemSort     = "home.itemSort"
    static let sourceFilter = "home.sourceFilter"
}

// MARK: - Snooze durations

private enum Snooze {
    static let oneHour: TimeInterval   = 3_600
    static let threeHours: TimeInterval = 10_800
    static let tomorrowHour: Int       = 9
}

struct HomeView: View {
    @Environment(AppStateStore.self) private var store
    @Binding var pendingNewItemTitle: String?

    @State private var showCompose = false
    @State private var composeInitialTitle: String = ""
    @State private var completedExpanded: Bool = false
    @State private var editingItem: Item?
    @State private var searchText: String = ""
    @State private var completingIDs: Set<UUID> = []
    @Namespace private var rowNamespace
    @AppStorage(StorageKey.itemSort)     private var sortOrder: String = ItemSort.dateAddedDesc.rawValue
    @AppStorage(StorageKey.sourceFilter) private var sourceFilterRaw: String = SourceFilter.all.rawValue

    private var currentSort: ItemSort {
        ItemSort(rawValue: sortOrder) ?? .dateAddedDesc
    }

    private var currentSourceFilter: SourceFilter {
        SourceFilter(rawValue: sourceFilterRaw) ?? .all
    }

    private var isSearching: Bool { !searchText.isEmpty }

    private var sortedActiveItems: [Item] {
        switch currentSort {
        case .dateAddedDesc:
            return store.activeItems.sorted {
                if $0.isPriority != $1.isPriority { return $0.isPriority }
                return $0.createdAt > $1.createdAt
            }
        case .dateAddedAsc:
            return store.activeItems.sorted { $0.createdAt < $1.createdAt }
        case .titleAZ:
            return store.activeItems.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
    }

    private var filteredActiveItems: [Item] {
        var items = sortedActiveItems

        // Source filter
        switch currentSourceFilter {
        case .all:    break
        case .manual: items = items.filter { $0.source == .manual }
        case .agent:  items = items.filter { $0.source == .agent }
        case .voice:  items = items.filter { $0.source == .voice }
        }

        // Text search
        if isSearching {
            items = items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        return items
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
        .toolbar { homeToolbar }
        .sheet(isPresented: $showCompose) {
            ItemComposeSheet(initialTitle: composeInitialTitle)
        }
        .sheet(item: $editingItem) { item in
            ItemEditSheet(item: item, sourceID: item.id, namespace: rowNamespace)
        }
        .onAppear { consumePendingTitle() }
        .onChange(of: pendingNewItemTitle) { consumePendingTitle() }
        .onChange(of: sortOrder)        { Haptics.selection() }
        .onChange(of: sourceFilterRaw)  { Haptics.selection() }
        .onChange(of: searchText) { _, new in
            if new.isEmpty { Haptics.light() }
        }
    }

    @ToolbarContentBuilder
    private var homeToolbar: some ToolbarContent {
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
            if !isSearching, let top = sortedActiveItems.first {
                Section {
                    NextActionHero(
                        item: top,
                        itemCount: sortedActiveItems.count,
                        namespace: rowNamespace,
                        onTap: { editingItem = top }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(listRowInsets)
                }
            }
            sourceFilterPicker
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

    private var listRowInsets: EdgeInsets {
        EdgeInsets(
            top: AppTheme.Spacing.xs,
            leading: AppTheme.Spacing.md,
            bottom: AppTheme.Spacing.xs,
            trailing: AppTheme.Spacing.md
        )
    }

    private var sourceFilterPicker: some View {
        Section {
            Picker("Source", selection: $sourceFilterRaw) {
                ForEach(SourceFilter.allCases) { filter in
                    Text(filter.label).tag(filter.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(listRowInsets)
        }
    }

    @ViewBuilder
    private var activeItemsSection: some View {
        Section {
            ForEach(filteredActiveItems) { item in
                itemRow(for: item)
            }
        }
    }

    private func itemRow(for item: Item) -> some View {
        let isCompleting = completingIDs.contains(item.id)
        return Button {
            Haptics.selection()
            editingItem = item
        } label: {
            ItemRow(item: item)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityHint("Double-tap to edit")
        .matchedTransitionSource(id: item.id, in: rowNamespace)
        .listRowInsets(listRowInsets)
        .scaleEffect(isCompleting ? 0.92 : 1.0)
        .opacity(isCompleting ? 0 : 1)
        .animation(AppTheme.Animation.spring, value: isCompleting)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            leadingSwipeActions(for: item)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            trailingSwipeActions(for: item)
        }
        .contextMenu {
            itemContextMenu(for: item)
        }
    }

    @ViewBuilder
    private func leadingSwipeActions(for item: Item) -> some View {
        Button {
            completeItem(item)
        } label: {
            Label("Done", systemImage: "checkmark.circle.fill")
        }
        .tint(.green)
    }

    @ViewBuilder
    private func trailingSwipeActions(for item: Item) -> some View {
        Button(role: .destructive) {
            store.deleteItem(item.id)
            Haptics.medium()
        } label: {
            Label("Delete", systemImage: "trash.fill")
        }
    }

    @ViewBuilder
    private func itemContextMenu(for item: Item) -> some View {
        Button {
            Haptics.selection()
            editingItem = item
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        Button {
            completeItem(item)
        } label: {
            Label("Complete", systemImage: "checkmark.circle")
        }
        Button {
            store.toggleItemPriority(item.id)
            Haptics.selection()
        } label: {
            Label(
                item.isPriority ? "Unstar" : "Star",
                systemImage: item.isPriority ? "star.slash" : "star"
            )
        }
        if item.reminderAt != nil {
            snoozeMenu(for: item)
        }
        Divider()
        Button(role: .destructive) {
            store.deleteItem(item.id)
            Haptics.medium()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func snoozeMenu(for item: Item) -> some View {
        Menu {
            Button("In 1 hour")     { snoozeItem(item, by: Snooze.oneHour) }
            Button("In 3 hours")    { snoozeItem(item, by: Snooze.threeHours) }
            Button("Tomorrow 9 am") { snoozeItemTomorrow(item) }
        } label: {
            Label("Snooze Reminder", systemImage: "bell.badge.slash")
        }
    }

    // MARK: - Complete with animation

    private func completeItem(_ item: Item) {
        guard !completingIDs.contains(item.id) else { return }
        completingIDs.insert(item.id)
        Haptics.success()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            store.setItemStatus(item.id, status: .done)
            completingIDs.remove(item.id)
        }
    }

    // MARK: - Deep-Link

    private func consumePendingTitle() {
        guard let title = pendingNewItemTitle else { return }
        pendingNewItemTitle = nil
        composeInitialTitle = title
        showCompose = true
    }

    // MARK: - Snooze

    private func snoozeItem(_ item: Item, by seconds: TimeInterval) {
        let newDate = Date().addingTimeInterval(seconds)
        applySnooze(to: item, date: newDate)
    }

    private func snoozeItemTomorrow(_ item: Item) {
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()),
              let date = cal.date(bySettingHour: Snooze.tomorrowHour, minute: 0, second: 0, of: tomorrow)
        else { return }
        applySnooze(to: item, date: date)
    }

    private func applySnooze(to item: Item, date: Date) {
        NotificationService.cancel(for: item.id)
        var updated = item
        updated.reminderAt = date
        store.updateItem(updated)
        Task {
            await NotificationService.scheduleReminder(for: item.id, title: item.title, at: date)
        }
        Haptics.success()
    }
}
