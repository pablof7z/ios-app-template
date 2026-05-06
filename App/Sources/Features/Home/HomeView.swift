import SwiftUI

// MARK: - Layout constants

private enum HomeLayout {
    /// Point size of the empty-state hero icon (checkmark circle).
    static let emptyStateIconSize: CGFloat = 72
}

struct HomeView: View {
    @Environment(AppStateStore.self) var store
    @Binding var pendingNewItemTitle: String?

    @State var showCompose = false
    @State var composeInitialTitle: String = ""
    @State var completedExpanded: Bool = false
    @State var editingItem: Item?
    @State var searchText: String = ""
    @State var completingIDs: Set<UUID> = []
    @State var selectedIDs: Set<UUID> = []
    @StateObject var celebration = CompletionCelebrationState()
    @Namespace var rowNamespace
    @Environment(\.editMode) var editMode
    @AppStorage(HomeStorageKey.itemSort)     var sortOrder: String = ItemSort.dateAddedDesc.rawValue
    @AppStorage(HomeStorageKey.sourceFilter) var sourceFilterRaw: String = SourceFilter.all.rawValue
    @AppStorage(HomeStorageKey.todayFilter)  var todayFilterRaw: String = TodayFilter.all.rawValue
    @AppStorage(HomeStorageKey.colorFilter)  var colorFilterRaw: String = ColorFilter.all.rawValue

    var currentSort: ItemSort {
        ItemSort(rawValue: sortOrder) ?? .dateAddedDesc
    }

    var currentSourceFilter: SourceFilter {
        SourceFilter(rawValue: sourceFilterRaw) ?? .all
    }

    var currentTodayFilter: TodayFilter {
        TodayFilter(rawValue: todayFilterRaw) ?? .all
    }

    var currentColorFilter: ColorFilter {
        ColorFilter(rawValue: colorFilterRaw) ?? .all
    }

    var isSearching: Bool { !searchText.isEmpty }

    var sortedActiveItems: [Item] {
        switch currentSort {
        case .dateAddedDesc:
            // When manual order is active, respect the user-defined sequence.
            // Items not yet in manualItemOrder (e.g. newly added) fall through to
            // createdAt-desc as a tiebreaker, which puts them at the top naturally.
            if isManualOrderActive {
                let order = store.state.manualItemOrder
                let positionOf: (Item) -> Int = { item in
                    order.firstIndex(of: item.id) ?? Int.max
                }
                return store.activeItems.sorted { lhs, rhs in
                    let lPos = positionOf(lhs)
                    let rPos = positionOf(rhs)
                    if lPos != rPos { return lPos < rPos }
                    // Tiebreaker for items not yet in the order array.
                    return lhs.createdAt > rhs.createdAt
                }
            }
            return store.activeItems.sorted {
                if $0.isPriority != $1.isPriority { return $0.isPriority }
                return $0.createdAt > $1.createdAt
            }
        case .dateAddedAsc:
            return store.activeItems.sorted { $0.createdAt < $1.createdAt }
        case .titleAZ:
            return store.activeItems.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .dueDateAsc:
            // Items with a due date sort first (earliest first); items without due date sort last.
            return store.activeItems.sorted {
                switch ($0.dueDate, $1.dueDate) {
                case let (lhs?, rhs?): return lhs < rhs
                case (_?, nil):        return true
                case (nil, _?):        return false
                case (nil, nil):       return $0.createdAt > $1.createdAt
                }
            }
        }
    }

    /// Drag-to-reorder is only active when there are no competing sort signals
    /// that would fight the persisted manual order. All filters must be clear
    /// and the sort must be "Newest First" (the natural / default mode).
    var isManualOrderActive: Bool {
        currentSort == .dateAddedDesc
            && !isSearching
            && currentSourceFilter == .all
            && currentTodayFilter == .all
            && currentColorFilter == .all
    }

    var filteredActiveItems: [Item] {
        var items = sortedActiveItems

        // Today filter — show only items due or reminding today
        if currentTodayFilter == .today {
            items = items.filter { currentTodayFilter.matches($0) }
        }

        // Source filter
        switch currentSourceFilter {
        case .all:    break
        case .manual: items = items.filter { $0.source == .manual }
        case .agent:  items = items.filter { $0.source == .agent }
        case .voice:  items = items.filter { $0.source == .voice }
        }

        // Color label filter
        if currentColorFilter != .all {
            items = items.filter { currentColorFilter.matches($0) }
        }

        // Text search
        if isSearching {
            items = items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        return items
    }

    var hasAnyItems: Bool {
        !store.activeItems.isEmpty || !store.completedItems.isEmpty
    }

    var isEditing: Bool { editMode?.wrappedValue.isEditing == true }

    var body: some View {
        Group {
            if !hasAnyItems {
                emptyState
            } else {
                itemList
            }
        }
        .overlay(CompletionCelebrationView(state: celebration))
        .navigationTitle("Home")
        .searchable(text: $searchText, prompt: "Search items")
        .toolbar { homeToolbar }
        .toolbar { batchToolbar }
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
        .onChange(of: todayFilterRaw)   { Haptics.selection() }
        .onChange(of: colorFilterRaw)   { Haptics.selection() }
        .onChange(of: searchText) { _, new in
            if new.isEmpty { Haptics.light() }
        }
        .onChange(of: isEditing) { _, editing in
            if !editing { selectedIDs = [] }
        }
    }

    @ToolbarContentBuilder
    var homeToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if !isEditing {
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
        }
        ToolbarItem(placement: .topBarLeading) {
            if !isEditing {
                HStack(spacing: AppTheme.Spacing.sm) {
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
                    colorFilterButton
                    todayFilterChip
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if hasAnyItems && !store.activeItems.isEmpty {
                EditButton()
                    .accessibilityLabel("Select Items")
            }
        }
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "checkmark.circle.dashed")
                .font(.system(size: HomeLayout.emptyStateIconSize, weight: .light))
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

}
