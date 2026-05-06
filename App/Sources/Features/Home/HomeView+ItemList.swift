import SwiftUI

// MARK: - Item list & row building

extension HomeView {

    // MARK: - Helpers

    /// Items completed so far today — drives the NextActionHero progress ring.
    var completedTodayCount: Int {
        store.completedItems.filter { Calendar.current.isDateInToday($0.updatedAt) }.count
    }

    // MARK: - List container

    var itemList: some View {
        List(selection: $selectedIDs) {
            if !isSearching && !isEditing, let top = sortedActiveItems.first {
                Section {
                    NextActionHero(
                        item: top,
                        itemCount: sortedActiveItems.count,
                        namespace: rowNamespace,
                        onTap: { editingItem = top },
                        completedToday: completedTodayCount
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

    // MARK: - Row insets (shared by list and section rows)

    var listRowInsets: EdgeInsets {
        EdgeInsets(
            top: AppTheme.Spacing.xs,
            leading: AppTheme.Spacing.md,
            bottom: AppTheme.Spacing.xs,
            trailing: AppTheme.Spacing.md
        )
    }

    // MARK: - Source filter picker

    var sourceFilterPicker: some View {
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

    // MARK: - Active items section

    @ViewBuilder
    var activeItemsSection: some View {
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

    // MARK: - Individual item row

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
