import SwiftUI

struct HomeItemsSection: View {
    @Environment(AppStateStore.self) private var store

    var onAdd: () -> Void

    @State private var showCompleted = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            header

            if activeItems.isEmpty {
                emptyState
            } else {
                activeList
            }

            if !completedItems.isEmpty {
                completedSection
            }
        }
        .animation(AppTheme.Animation.spring, value: activeItems.count)
        .animation(AppTheme.Animation.spring, value: completedItems.count)
    }

    private var header: some View {
        HStack {
            Text("Items")
                .font(AppTheme.Typography.headline)
            if !activeItems.isEmpty {
                Text("\(activeItems.count)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .glassEffect(.regular, in: .capsule)
            }
            Spacer()
            Button {
                Haptics.selection()
                onAdd()
            } label: {
                Label("New", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("New item")
        }
        .padding(.horizontal, AppTheme.Spacing.xs)
    }

    private var activeItems: [Item] {
        store.activeItems.sorted { $0.createdAt > $1.createdAt }
    }

    private var completedItems: [Item] {
        store.state.items
            .filter { !$0.deleted && $0.status == .done }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var activeList: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Array(activeItems.enumerated()), id: \.element.id) { index, item in
                    ItemRow(
                        item: item,
                        onToggle: { toggleDone(item) },
                        onDelete: { deleteItem(item) }
                    )
                    .transition(.scale.combined(with: .opacity))
                    if index < activeItems.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                            .opacity(0.4)
                    }
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Button {
                Haptics.selection()
                withAnimation(AppTheme.Animation.spring) {
                    showCompleted.toggle()
                }
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Completed")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                    Text("\(completedItems.count)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .glassEffect(.regular, in: .capsule)
                    Spacer()
                }
                .contentShape(Rectangle())
                .padding(.horizontal, AppTheme.Spacing.xs)
                .padding(.top, AppTheme.Spacing.sm)
            }
            .buttonStyle(.plain)

            if showCompleted {
                GlassEffectContainer(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(completedItems.enumerated()), id: \.element.id) { index, item in
                            ItemRow(
                                item: item,
                                onToggle: { toggleDone(item) },
                                onDelete: { deleteItem(item) }
                            )
                            .transition(.scale.combined(with: .opacity))
                            if index < completedItems.count - 1 {
                                Divider()
                                    .padding(.leading, 56)
                                    .opacity(0.4)
                            }
                        }
                    }
                    .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var emptyState: some View {
        Button {
            Haptics.selection()
            onAdd()
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add your first item")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(.primary)
                    Text("Track tasks, requests, and follow-ups.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                .regular.tint(.green.opacity(0.08)).interactive(),
                in: .rect(cornerRadius: AppTheme.Corner.lg)
            )
        }
        .buttonStyle(.plain)
    }

    private func toggleDone(_ item: Item) {
        Haptics.medium()
        let nextStatus: ItemStatus = item.status == .done ? .pending : .done
        withAnimation(AppTheme.Animation.spring) {
            store.setItemStatus(item.id, status: nextStatus)
        }
    }

    private func deleteItem(_ item: Item) {
        Haptics.warning()
        withAnimation(AppTheme.Animation.spring) {
            store.deleteItem(item.id)
        }
    }
}
