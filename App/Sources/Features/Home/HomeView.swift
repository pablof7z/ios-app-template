import SwiftUI

struct HomeView: View {
    @Environment(AppStateStore.self) private var store
    @Binding var pendingNewItemTitle: String?

    @State private var showCompose = false
    @State private var composeInitialTitle: String = ""
    @State private var completedExpanded: Bool = false
    @State private var editingItem: Item?
    @State private var searchText: String = ""

    private var isSearching: Bool { !searchText.isEmpty }

    private var filteredActiveItems: [Item] {
        guard isSearching else { return store.activeItems }
        return store.activeItems.filter {
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
                    Label(reminder.formatted(date: .abbreviated, time: .shortened),
                          systemImage: "bell.fill")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.orange)
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
