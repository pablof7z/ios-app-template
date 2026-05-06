import AppIntents
import SwiftUI

// MARK: - Action helpers

extension HomeView {

    // MARK: Complete with animation

    /// Animates the row out then marks the item done in the store.
    /// After the status flip we donate a `MarkItemDoneIntent` so Siri learns
    /// the user's completion patterns (time-of-day, location) and can offer
    /// proactive suggestions on the Lock Screen and in Siri Suggestions.
    func completeItem(_ item: Item) {
        guard !completingIDs.contains(item.id) else { return }
        completingIDs.insert(item.id)
        Haptics.success()
        celebration.trigger()
        Task { @MainActor in
            try? await Task.sleep(for: AppTheme.Timing.itemCompletionDelay)
            store.setItemStatus(item.id, status: .done)
            completingIDs.remove(item.id)
            donateMarkDoneIntent(for: item)
        }
    }

    // MARK: - Siri donation

    /// Donates a `MarkItemDoneIntent` interaction to Siri so the system can
    /// predict and surface the shortcut at appropriate moments.
    /// The donation runs off the main actor so it never blocks the UI.
    private func donateMarkDoneIntent(for item: Item) {
        var intent = MarkItemDoneIntent()
        intent.target = ItemEntity(from: item)
        Task.detached(priority: .background) {
            try? await IntentDonationManager.shared.donate(intent: intent)
        }
    }

    // MARK: Deep-Link

    /// Consumes a pending title from the deep-link handler, opening the compose sheet.
    func consumePendingTitle() {
        guard let title = pendingNewItemTitle else { return }
        pendingNewItemTitle = nil
        composeInitialTitle = title
        showCompose = true
    }

    /// Consumes a pending item ID delivered via Handoff continuation.
    /// Opens the edit sheet for the matching item, or silently no-ops when
    /// the item is not present on this device yet (e.g. iCloud hasn't synced).
    func consumePendingEditID() {
        guard let id = pendingEditItemID else { return }
        pendingEditItemID = nil
        guard let item = store.state.items.first(where: { $0.id == id && !$0.deleted }) else { return }
        editingItem = item
    }
}
