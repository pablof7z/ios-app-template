import Foundation

/// Defines the tools the agent can call and dispatches them to AppStateStore.
/// Add new tools by:
///   1. Adding a schema entry to `schema`
///   2. Adding a case to `dispatch`
enum AgentTools {

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
        let args = (try? JSONSerialization.jsonObject(with: Data(argsJSON.utf8)) as? [String: Any]) ?? [:]

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
            let title = store.state.items.first { $0.id == id }?.title ?? "item"
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
            let title = store.state.items.first { $0.id == id }?.title ?? "item"
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
                summary: "Saved note \"\(text.prefix(40))\(text.count > 40 ? "…" : "")\""
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
                summary: "Remembered \"\(content.prefix(40))\(content.count > 40 ? "…" : "")\""
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
        return (try? String(data: JSONSerialization.data(withJSONObject: result), encoding: .utf8)) ?? "{\"success\":true}"
    }

    private static func error(_ message: String) -> String {
        let payload: [String: Any] = ["error": message]
        return (try? String(data: JSONSerialization.data(withJSONObject: payload), encoding: .utf8)) ?? "{\"error\":\"unknown\"}"
    }
}
