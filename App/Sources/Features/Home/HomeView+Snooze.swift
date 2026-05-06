import SwiftUI

// MARK: - Snooze helpers

extension HomeView {
    /// Reschedules the item's reminder `seconds` from now.
    func snoozeItem(_ item: Item, by seconds: TimeInterval) {
        let newDate = Date().addingTimeInterval(seconds)
        applySnooze(to: item, date: newDate)
    }

    /// Reschedules the item's reminder for tomorrow at `HomeSnooze.tomorrowHour`.
    func snoozeItemTomorrow(_ item: Item) {
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()),
              let date = cal.date(bySettingHour: HomeSnooze.tomorrowHour, minute: 0, second: 0, of: tomorrow)
        else { return }
        applySnooze(to: item, date: date)
    }

    /// Cancels any existing notification and saves the new reminder date.
    func applySnooze(to item: Item, date: Date) {
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
