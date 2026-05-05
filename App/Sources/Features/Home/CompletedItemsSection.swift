import SwiftUI

/// Collapsible section showing completed items with an "Undo" swipe and a "Clear All" button.
struct CompletedItemsSection: View {
    @Environment(AppStateStore.self) private var store

    @Binding var isExpanded: Bool
    @State private var showClearConfirm = false

    var body: some View {
        Section {
            if isExpanded {
                completedRows
            }
        } header: {
            completedHeader
        }
        .animation(AppTheme.Animation.spring, value: isExpanded)
        .animation(AppTheme.Animation.spring, value: store.completedItems.count)
        .alert("Clear all completed?", isPresented: $showClearConfirm) {
            Button("Clear All", role: .destructive) {
                store.clearCompletedItems()
                Haptics.success()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes all completed items.")
        }
    }

    @ViewBuilder
    private var completedRows: some View {
        ForEach(store.completedItems) { item in
            CompletedItemRow(item: item)
                .listRowInsets(EdgeInsets(
                    top: AppTheme.Spacing.xs,
                    leading: AppTheme.Spacing.md,
                    bottom: AppTheme.Spacing.xs,
                    trailing: AppTheme.Spacing.md
                ))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    restoreAction(for: item)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    deleteAction(for: item)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private func restoreAction(for item: Item) -> some View {
        Button {
            store.setItemStatus(item.id, status: .pending)
            Haptics.success()
        } label: {
            Label("Restore", systemImage: "arrow.uturn.left.circle.fill")
        }
        .tint(.blue)
    }

    @ViewBuilder
    private func deleteAction(for item: Item) -> some View {
        Button(role: .destructive) {
            store.deleteItem(item.id)
            Haptics.medium()
        } label: {
            Label("Delete", systemImage: "trash.fill")
        }
    }

    // MARK: - Header

    private var completedHeader: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            disclosureButton
            Spacer(minLength: 0)
            if isExpanded && !store.completedItems.isEmpty {
                clearAllButton
            }
        }
    }

    private var disclosureButton: some View {
        Button {
            Haptics.selection()
            withAnimation(AppTheme.Animation.spring) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(AppTheme.Animation.spring, value: isExpanded)
                Text("Completed")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                Text("(\(store.completedItems.count))")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var clearAllButton: some View {
        Button {
            Haptics.selection()
            showClearConfirm = true
        } label: {
            Text("Clear All")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(.red.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Completed Item Row

private struct CompletedItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.green.opacity(0.6))

            Text(item.title)
                .font(AppTheme.Typography.body)
                .foregroundStyle(.secondary)
                .strikethrough(true, color: .secondary.opacity(0.5))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .contentShape(Rectangle())
    }
}
