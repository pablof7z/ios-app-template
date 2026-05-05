import AppIntents
import Foundation

/// Marks an existing pending item as done. The user picks an item from a
/// Shortcuts picker (powered by `ItemEntityQuery.suggestedEntities`) or
/// dictates / types a title that Siri matches against `IndexedEntity`.
struct MarkItemDoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Item Done"
    static let description = IntentDescription(
        "Mark one of your pending items as done."
    )
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Item",
        description: "Which item to complete.",
        requestValueDialog: "Which one?"
    )
    var target: ItemEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // CRITICAL: never fall back to a fresh AppState() on decode failure —
        // saving on top would clobber the rest of the user's items. Surface an
        // error dialog instead and leave persisted state untouched.
        var state: AppState
        do {
            state = try Persistence.load()
        } catch {
            FileHandle.standardError.write(Data("MarkItemDoneIntent: load failed: \(error)\n".utf8))
            return .result(dialog: "I couldn't read your data. Open the app once and try again.")
        }
        guard let idx = state.items.firstIndex(where: { $0.id == target.id }) else {
            return .result(dialog: "I couldn't find that item.")
        }
        guard !state.items[idx].deleted else {
            return .result(dialog: "That item was deleted.")
        }
        guard state.items[idx].status != .done else {
            return .result(dialog: "That's already done.")
        }

        state.items[idx].status = .done
        state.items[idx].updatedAt = Date()
        Persistence.save(state)

        return .result(dialog: "Marked “\(state.items[idx].title)” as done.")
    }
}
