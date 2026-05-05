import Foundation

/// Builds the system prompt injected at position 0 of every agent run.
/// Includes current state context, friend list, and persisted memories.
enum AgentPrompt {
    static func build(for state: AppState) -> String {
        var sections: [String] = []

        sections.append("""
        You are a helpful personal assistant embedded in an iOS app.
        Today is \(Self.dateString).
        Help the user manage their tasks, notes, and collaborate with their friends.
        Be concise and action-oriented.
        """)

        let activeItems = state.items.filter { !$0.deleted && $0.status == .pending }
        if !activeItems.isEmpty {
            let list = activeItems.map { item -> String in
                var line = "- [\(item.id)] \(item.title)"
                if let name = item.requestedByDisplayName {
                    line += " (from \(name))"
                }
                return line
            }.joined(separator: "\n")
            sections.append("## Pending Items\n\(list)")
        }

        if !state.friends.isEmpty {
            // Expose only displayName + truncated public identifier. Internal
            // UUIDs have no value to the LLM (no tool consumes a friend UUID),
            // and leaking them broadens the prompt-injection / data-exfiltration
            // surface unnecessarily.
            let list = state.friends
                .map { "- \($0.displayName) (\($0.shortIdentifier))" }
                .joined(separator: "\n")
            sections.append("## Friends\n\(list)")
        }

        let memories = state.agentMemories.filter { !$0.deleted }
        if !memories.isEmpty {
            let list = memories.map { "- \($0.content)" }.joined(separator: "\n")
            sections.append("## What You Know About the User\n\(list)")
        }

        return sections.joined(separator: "\n\n")
    }

    private static var dateString: String {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .short
        return f.string(from: Date())
    }
}
