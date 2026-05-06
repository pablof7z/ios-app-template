import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AppTemplate", category: "AgentChatTranscriptExport")

// MARK: - AgentChatTranscriptExport

/// Formats a chat transcript as a Markdown document and writes it to a
/// temporary file that can be shared via `ShareLink` or `ShareSheet`.
enum AgentChatTranscriptExport {

    // MARK: - Constants

    private enum Const {
        static let tmpFilename = "agent-transcript.md"
        static let separator = "\n\n---\n\n"
    }

    // MARK: - Public API

    /// Builds a Markdown string from `messages` and writes it to a temp file.
    /// Returns the file URL on success, or `nil` if writing fails.
    static func write(_ messages: [ChatMessage]) -> URL? {
        let markdown = format(messages)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(Const.tmpFilename)
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            logger.error("AgentChatTranscriptExport: failed to write tmp file: \(error, privacy: .public)")
            return nil
        }
    }

    // MARK: - Formatting

    /// Produces a human-readable Markdown transcript from `messages`.
    static func format(_ messages: [ChatMessage]) -> String {
        guard !messages.isEmpty else { return "" }
        let header = buildHeader(messages: messages)
        let body = messages.map(formatMessage).joined(separator: Const.separator)
        return header + "\n\n" + body + "\n"
    }

    // MARK: - Private helpers

    private static func buildHeader(messages: [ChatMessage]) -> String {
        let first = messages.first?.timestamp
        let last  = messages.last?.timestamp
        let dateRange: String
        if let first, let last, first != last {
            dateRange = "\(formatted(first)) – \(formatted(last))"
        } else if let first {
            dateRange = formatted(first)
        } else {
            dateRange = ""
        }
        return "# Agent Transcript\n\n_\(dateRange)_\n\n_\(messages.count) message\(messages.count == 1 ? "" : "s")_"
    }

    private static func formatMessage(_ message: ChatMessage) -> String {
        let label = roleLabel(for: message.role)
        let time  = formatted(message.timestamp)
        return "**\(label)** · \(time)\n\n\(message.text)"
    }

    private static func roleLabel(for role: ChatMessage.Role) -> String {
        switch role {
        case .user:
            return "You"
        case .assistant:
            return "Agent"
        case .toolBatch(_, let count):
            return "Tools (\(count) action\(count == 1 ? "" : "s"))"
        case .error:
            return "Error"
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static func formatted(_ date: Date) -> String {
        timestampFormatter.string(from: date)
    }
}
