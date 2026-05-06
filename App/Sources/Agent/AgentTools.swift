import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AppTemplate", category: "AgentTools")

/// Defines the tools the agent can call and dispatches them to AppStateStore.
/// Add new tools by:
///   1. Adding a schema entry to `schema`
///   2. Adding a case to `dispatch`
enum AgentTools {

    // MARK: - Constants

    /// Maximum number of characters used when truncating text in activity summaries.
    private static let summaryTruncationLength = 40
    /// Placeholder title used when a matching item cannot be found in the store.
    private static let unknownItemTitle = "item"

    // MARK: - JSON Schema (OpenAI tool format)

    @MainActor
    static var schema: [[String: Any]] {
        [
            tool(
                name: "create_item",
                description: "Create a new task or to-do item for the user.",
                properties: ["title": ["type": "string", "description": "The task title"]],
                required: ["title"]
            ),
            tool(
                name: "mark_item_done",
                description: "Mark a task as completed by its ID.",
                properties: ["id": ["type": "string", "description": "UUID of the item"]],
                required: ["id"]
            ),
            tool(
                name: "delete_item",
                description: "Delete a task by its ID.",
                properties: ["id": ["type": "string", "description": "UUID of the item"]],
                required: ["id"]
            ),
            tool(
                name: "create_note",
                description: "Save a note or reflection.",
                properties: [
                    "text": ["type": "string", "description": "Note content"],
                    "kind": ["type": "string", "enum": ["free", "reflection"], "description": "Note type"],
                ],
                required: ["text"]
            ),
            tool(
                name: "record_memory",
                description: "Save something important to remember about the user for future sessions.",
                properties: ["content": ["type": "string", "description": "The fact to remember"]],
                required: ["content"]
            ),
        ]
    }

    // MARK: - Dispatcher

    @MainActor
    static func dispatch(name: String, argsJSON: String, store: AppStateStore, batchID: UUID) async -> String {
        let args: [String: Any]
        do {
            args = try JSONSerialization.jsonObject(with: Data(argsJSON.utf8)) as? [String: Any] ?? [:]
        } catch {
            logger.error("AgentTools: failed to parse argsJSON for tool '\(name, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            args = [:]
        }

        switch name {
        case "create_item":
            guard let title = args["title"] as? String, !title.isEmpty else {
                return error("Missing or empty 'title'")
            }
            let item = store.addItem(title: title, source: .agent)
            store.recordAgentActivity(.init(
                batchID: batchID,
                kind: .itemCreated(itemID: item.id),
                summary: "Created \"\(item.title)\""
            ))
            return success(["id": item.id.uuidString, "title": item.title])

        case "mark_item_done":
            guard let idStr = args["id"] as? String, let id = UUID(uuidString: idStr) else {
                return error("Invalid or missing 'id'")
            }
            guard let prior = store.itemStatus(id) else {
                return error("Item not found")
            }
            store.setItemStatus(id, status: .done)
            let title = store.state.items.first { $0.id == id }?.title ?? Self.unknownItemTitle
            store.recordAgentActivity(.init(
                batchID: batchID,
                kind: .itemMarkedDone(itemID: id, priorStatus: prior),
                summary: "Marked \"\(title)\" done"
            ))
            return success(["id": idStr])

        case "delete_item":
            guard let idStr = args["id"] as? String, let id = UUID(uuidString: idStr) else {
                return error("Invalid or missing 'id'")
            }
            let title = store.state.items.first { $0.id == id }?.title ?? Self.unknownItemTitle
            store.deleteItem(id)
            store.recordAgentActivity(.init(
                batchID: batchID,
                kind: .itemDeleted(itemID: id),
                summary: "Deleted \"\(title)\""
            ))
            return success(["id": idStr])

        case "create_note":
            guard let text = args["text"] as? String, !text.isEmpty else {
                return error("Missing or empty 'text'")
            }
            // `systemEvent` is intentionally excluded — that kind is reserved
            // for app-generated entries; the agent must not be able to forge it.
            let kindStr = args["kind"] as? String ?? "free"
            let kind: NoteKind = switch kindStr {
            case "reflection": .reflection
            default: .free
            }
            let note = store.addNote(text: text, kind: kind)
            store.recordAgentActivity(.init(
                batchID: batchID,
                kind: .noteCreated(noteID: note.id),
                summary: "Saved note \"\(text.prefix(Self.summaryTruncationLength))\(text.count > Self.summaryTruncationLength ? "…" : "")\""
            ))
            return success(["id": note.id.uuidString])

        case "record_memory":
            guard let content = args["content"] as? String, !content.isEmpty else {
                return error("Missing or empty 'content'")
            }
            let mem = store.addAgentMemory(content: content)
            store.recordAgentActivity(.init(
                batchID: batchID,
                kind: .memoryRecorded(memoryID: mem.id),
                summary: "Remembered \"\(content.prefix(Self.summaryTruncationLength))\(content.count > Self.summaryTruncationLength ? "…" : "")\""
            ))
            return success(["id": mem.id.uuidString])

        default:
            return error("Unknown tool: \(name)")
        }
    }

    // MARK: - Helpers

    private static func tool(
        name: String,
        description: String,
        properties: [String: Any],
        required: [String]
    ) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": required,
                ] as [String: Any],
            ] as [String: Any],
        ]
    }

    private static func success(_ payload: [String: Any] = [:]) -> String {
        var result: [String: Any] = ["success": true]
        result.merge(payload) { _, new in new }
        do {
            return try String(data: JSONSerialization.data(withJSONObject: result), encoding: .utf8) ?? "{\"success\":true}"
        } catch {
            logger.error("AgentTools: failed to serialize success payload: \(error.localizedDescription, privacy: .public)")
            return "{\"success\":true}"
        }
    }

    private static func error(_ message: String) -> String {
        let payload: [String: Any] = ["error": message]
        do {
            return try String(data: JSONSerialization.data(withJSONObject: payload), encoding: .utf8) ?? "{\"error\":\"unknown\"}"
        } catch {
            logger.error("AgentTools: failed to serialize error payload '\(message, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return "{\"error\":\"unknown\"}"
        }
    }
}
