import SwiftUI

struct HomeView: View {
    @Environment(AppStateStore.self) private var store
    @Binding var pendingNewItemTitle: String?

    @State private var showCompose = false
    @State private var composeInitialTitle: String = ""
    @State private var completedExpanded: Bool = false

    private var hasAnyItems: Bool {
        !store.activeItems.isEmpty || !store.completedItems.isEmpty
    }

    var body: some View {
        Group {
            if hasAnyItems {
                itemList
            } else {
                emptyState
            }
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    composeInitialTitle = ""
                    showCompose = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showCompose) {
            ItemComposeSheet(initialTitle: composeInitialTitle)
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
            Section {
                ForEach(store.activeItems) { item in
                    ItemRow(item: item)
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

            if !store.completedItems.isEmpty {
                CompletedItemsSection(isExpanded: $completedExpanded)
            }
        }
        .listStyle(.plain)
        .animation(AppTheme.Animation.spring, value: store.activeItems.count)
        .animation(AppTheme.Animation.spring, value: store.completedItems.isEmpty)
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
