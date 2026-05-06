import AppIntents
import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AppTemplate", category: "AddItemIntent")

/// Adds a new item to the user's list. Exposed to Siri, the Shortcuts app, and
/// the Action Button via `AppTemplateShortcuts`.
///
/// **Process model.** This intent runs in the host extension that Siri /
/// Shortcuts spawns. That process is logically separate from a running app
/// process — it cannot reach the in-memory `AppStateStore`. We therefore load
/// and save through `Persistence` (App Group `UserDefaults`), the same trick
/// `ToggleCommitmentIntent` uses in win-the-day.
///
/// **Foreground app caveat.** If the app is in the foreground when Siri fires
/// this intent, the live `AppStateStore` won't observe the new item until the
/// next launch — there is no cross-process change notification. Acceptable for
/// a template; a real app would either listen for `UserDefaults.didChangeNotification`
/// on the App Group suite or rebuild on `scenePhase == .active`.
struct AddItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Item"
    static let description = IntentDescription(
        "Quickly add a new item to your list."
    )

    /// Stay in Siri / Shortcuts after running — no need to yank the user into
    /// the app for a one-shot capture.
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Item",
        description: "What you want to add.",
        requestValueDialog: "What should I add?"
    )
    var title: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "I need something to add.")
        }

        // CRITICAL: never fall back to a fresh AppState() on decode failure —
        // saving on top would obliterate the user's existing items. Only swallow
        // the "no persisted state yet" case (first launch); on real decode errors,
        // surface a dialog and bail so the user's data stays intact.
        let state: AppState
        do {
            state = try Persistence.load()
        } catch {
            logger.error("AddItemIntent: load failed: \(error, privacy: .public)")
            return .result(dialog: "I couldn't read your data. Open the app once and try again.")
        }
        var nextState = state
        let item = Item(title: trimmed, source: .manual)
        nextState.items.append(item)
        Persistence.save(nextState)

        return .result(dialog: "Added “\(trimmed)”.")
    }
}

/// Returns the count of pending (non-deleted, not-done) items. Useful in
/// Shortcuts for assembling read-only flows ("How many things am I doing?").
struct PendingItemCountIntent: AppIntent {
    static let title: LocalizedStringResource = "Count Pending Items"
    static let description = IntentDescription(
        "Returns how many items are still pending."
    )
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        // Read-only — safe to fall back to an empty state on decode failure.
        let state: AppState
        do {
            state = try Persistence.load()
        } catch {
            logger.error("PendingItemCountIntent: load failed: \(error, privacy: .public)")
            state = AppState()
        }
        let count = state.items.filter { !$0.deleted && $0.status == .pending }.count
        let dialog: IntentDialog
        switch count {
        case 0:  dialog = "Nothing pending."
        case 1:  dialog = "1 pending item."
        default: dialog = "\(count) pending items."
        }
        return .result(value: count, dialog: dialog)
    }
}
