import SwiftUI

// MARK: - Row swipe actions, context menu, and snooze menu

extension HomeView {

    @ViewBuilder
    func leadingSwipeActions(for item: Item) -> some View {
        Button {
            completeItem(item)
        } label: {
            Label("Done", systemImage: "checkmark.circle.fill")
        }
        .tint(.green)
    }

    @ViewBuilder
    func trailingSwipeActions(for item: Item) -> some View {
        Button(role: .destructive) {
            store.deleteItem(item.id)
            Haptics.medium()
        } label: {
            Label("Delete", systemImage: "trash.fill")
        }
    }

    @ViewBuilder
    func itemContextMenu(for item: Item) -> some View {
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
        ShareLink(item: item.shareText) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .simultaneousGesture(TapGesture().onEnded { ReviewPrompt.recordItemShared() })
        Divider()
        Button(role: .destructive) {
            store.deleteItem(item.id)
            Haptics.medium()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    func snoozeMenu(for item: Item) -> some View {
        Menu {
            Button("In 1 hour")     { snoozeItem(item, by: HomeSnooze.oneHour) }
            Button("In 3 hours")    { snoozeItem(item, by: HomeSnooze.threeHours) }
            Button("Tomorrow 9 am") { snoozeItemTomorrow(item) }
        } label: {
            Label("Snooze Reminder", systemImage: "bell.badge.slash")
        }
    }
}
