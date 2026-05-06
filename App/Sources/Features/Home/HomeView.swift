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
    @State private var completedExpanded: Bool = false
    @State var editingItem: Item?
    @State private var searchText: String = ""
    @State var completingIDs: Set<UUID> = []
    @State var selectedIDs: Set<UUID> = []
    @StateObject var celebration = CompletionCelebrationState()
    @Namespace private var rowNamespace
    @Environment(\.editMode) var editMode
    @AppStorage(HomeStorageKey.itemSort)     private var sortOrder: String = ItemSort.dateAddedDesc.rawValue
    @AppStorage(HomeStorageKey.sourceFilter) private var sourceFilterRaw: String = SourceFilter.all.rawValue
    @AppStorage(HomeStorageKey.todayFilter)  var todayFilterRaw: String = TodayFilter.all.rawValue
    @AppStorage(HomeStorageKey.colorFilter)  var colorFilterRaw: String = ColorFilter.all.rawValue

    var currentSort: ItemSort {
        ItemSort(rawValue: sortOrder) ?? .dateAddedDesc
    }

    private var currentSourceFilter: SourceFilter {
        SourceFilter(rawValue: sourceFilterRaw) ?? .all
    }

    var currentTodayFilter: TodayFilter {
        TodayFilter(rawValue: todayFilterRaw) ?? .all
    }

    var currentColorFilter: ColorFilter {
        ColorFilter(rawValue: colorFilterRaw) ?? .all
    }

    var isSearching: Bool { !searchText.isEmpty }

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

    private var hasAnyItems: Bool {
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
    private var homeToolbar: some ToolbarContent {
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

    private var emptyState: some View {
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

    // MARK: - Item List

    private var itemList: some View {
        List(selection: $selectedIDs) {
            if !isSearching && !isEditing, let top = sortedActiveItems.first {
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
            if !isEditing {
                sourceFilterPicker
            }
            if isSearching && filteredActiveItems.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowSeparator(.hidden)
            } else if currentTodayFilter == .today && filteredActiveItems.isEmpty && !isSearching {
                todayEmptyState
                    .listRowSeparator(.hidden)
            } else {
                activeItemsSection
            }
            if !isSearching && !isEditing && !store.completedItems.isEmpty {
                CompletedItemsSection(isExpanded: $completedExpanded)
            }
        }
        .listStyle(.plain)
        .animation(AppTheme.Animation.spring, value: filteredActiveItems.count)
        .animation(AppTheme.Animation.spring, value: pinnedItems.count)
        .animation(AppTheme.Animation.spring, value: overdueItems.count)
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
        if showOverdueSection {
            overdueSection
            Section {
                ForEach(nonOverdueItems) { item in
                    itemRow(for: item)
                }
            } header: {
                if !overdueItems.isEmpty {
                    Text("Upcoming")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        } else if showPinnedSection {
            pinnedSection
            Section {
                ForEach(nonPinnedItems) { item in
                    itemRow(for: item)
                }
            } header: {
                if !nonPinnedItems.isEmpty {
                    Text("Other")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Section {
                ForEach(filteredActiveItems) { item in
                    itemRow(for: item)
                }
            }
        }
    }

    func itemRow(for item: Item) -> some View {
        let isCompleting = completingIDs.contains(item.id)
        return Button {
            guard !isEditing else { return }
            Haptics.selection()
            editingItem = item
        } label: {
            ItemRow(item: item)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityHint(isEditing ? "Double-tap to select" : "Double-tap to edit")
        .matchedTransitionSource(id: item.id, in: rowNamespace)
        .listRowInsets(listRowInsets)
        .scaleEffect(isCompleting ? 0.92 : 1.0)
        .opacity(isCompleting ? 0 : 1)
        .tag(item.id)
        .animation(AppTheme.Animation.spring, value: isCompleting)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !isEditing { leadingSwipeActions(for: item) }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isEditing { trailingSwipeActions(for: item) }
        }
        .contextMenu {
            if !isEditing { itemContextMenu(for: item) }
        }
    }

}
