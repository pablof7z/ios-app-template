import SwiftUI

// MARK: - Action helpers

extension HomeView {

    // MARK: Complete with animation

    /// Animates the row out then marks the item done in the store.
    func completeItem(_ item: Item) {
        guard !completingIDs.contains(item.id) else { return }
        completingIDs.insert(item.id)
        Haptics.success()
        celebration.trigger()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            store.setItemStatus(item.id, status: .done)
            completingIDs.remove(item.id)
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
}
