@preconcurrency import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// Indexes user-visible domain objects into iOS Spotlight so they can be
/// surfaced from system search and from Siri. Tapping a result deep-links
/// back into the app via `NSUserActivity` of type `CSSearchableItemActionType`.
///
/// Strategy: a full idempotent re-index of `activeItems + activeNotes` driven
/// from `AppStateStore.init` and from each mutating store method. The data set
/// is small (UI-bounded by what fits in a single user's task list / journal),
/// so the cost of rebuilding the index per mutation is negligible compared to
/// the complexity of an incremental indexer.
///
/// Index lives in two domains:
///   - `Domain.items`  — todos / tasks (only `pending` items appear)
///   - `Domain.notes`  — journal-style notes (only non-deleted)
///
/// Each domain is fully replaced on every reindex, so soft-deleted or completed
/// records disappear from search automatically.
@MainActor
enum SpotlightIndexer {

    // MARK: - Domains

    enum Domain: String, CaseIterable {
        case items = "com.apptemplate.spotlight.items"
        case notes = "com.apptemplate.spotlight.notes"
    }

    // MARK: - Identifier scheme
    //
    // Spotlight identifiers are namespaced as "<domain-prefix>:<uuid>" so a
    // continuation handler can route back to the correct screen without
    // consulting Spotlight's own domain identifier.

    private static let itemPrefix = "item:"
    private static let notePrefix = "note:"

    static func itemIdentifier(_ id: UUID) -> String { itemPrefix + id.uuidString }
    static func noteIdentifier(_ id: UUID) -> String { notePrefix + id.uuidString }

    /// Decoded result from a Spotlight continuation activity.
    enum DeepLink: Equatable {
        case item(UUID)
        case note(UUID)
    }

    /// Parses an identifier produced by this indexer back into a `DeepLink`.
    /// Returns nil for unknown / malformed values.
    static func deepLink(from identifier: String) -> DeepLink? {
        if identifier.hasPrefix(itemPrefix) {
            let raw = String(identifier.dropFirst(itemPrefix.count))
            return UUID(uuidString: raw).map(DeepLink.item)
        }
        if identifier.hasPrefix(notePrefix) {
            let raw = String(identifier.dropFirst(notePrefix.count))
            return UUID(uuidString: raw).map(DeepLink.note)
        }
        return nil
    }

    /// Convenience that pulls the Spotlight identifier out of a continuation
    /// `NSUserActivity` and decodes it.
    static func deepLink(from activity: NSUserActivity) -> DeepLink? {
        guard activity.activityType == CSSearchableItemActionType,
              let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return nil }
        return deepLink(from: id)
    }

    // MARK: - Reindex

    /// Replaces the contents of both Spotlight domains with current state.
    /// Safe to call from any mutation site — idempotent, and the underlying
    /// `CSSearchableIndex` calls are non-blocking.
    static func reindex(state: AppState) {
        let items = state.items
            .filter { !$0.deleted && $0.status == .pending }
            .map(makeSearchable(from:))

        let notes = state.notes
            .filter { !$0.deleted }
            .map(makeSearchable(from:))

        let index = CSSearchableIndex.default()

        index.deleteSearchableItems(withDomainIdentifiers: [Domain.items.rawValue]) { _ in
            guard !items.isEmpty else { return }
            index.indexSearchableItems(items) { _ in }
        }

        index.deleteSearchableItems(withDomainIdentifiers: [Domain.notes.rawValue]) { _ in
            guard !notes.isEmpty else { return }
            index.indexSearchableItems(notes) { _ in }
        }
    }

    /// Removes everything this app has put into Spotlight. Useful when the
    /// user clears all data.
    static func clearAll() {
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: Domain.allCases.map(\.rawValue)
        ) { _ in }
    }

    // MARK: - Builders

    private static func makeSearchable(from item: Item) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: UTType.text)
        attrs.title = item.title
        attrs.contentDescription = item.requestedByDisplayName.map { "From \($0)" }
        attrs.contentCreationDate = item.createdAt
        attrs.contentModificationDate = item.updatedAt
        attrs.keywords = ["task", "todo", "item"]

        return CSSearchableItem(
            uniqueIdentifier: itemIdentifier(item.id),
            domainIdentifier: Domain.items.rawValue,
            attributeSet: attrs
        )
    }

    private static func makeSearchable(from note: Note) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: UTType.text)
        // Notes have no title, just text — use the first line as the title and
        // the full body as the description so Spotlight can match either.
        let firstLine = note.text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? note.text
        attrs.title = firstLine
        attrs.contentDescription = note.text
        attrs.contentCreationDate = note.createdAt
        attrs.keywords = ["note", "journal", note.kind.rawValue]

        return CSSearchableItem(
            uniqueIdentifier: noteIdentifier(note.id),
            domainIdentifier: Domain.notes.rawValue,
            attributeSet: attrs
        )
    }
}
