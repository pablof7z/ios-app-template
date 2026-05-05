import Foundation
import Observation

@MainActor
@Observable
final class ChatHistoryStore {

    static let shared = ChatHistoryStore()

    private static let filename = "chat_history.json"
    private static let maxMessages = 100

    private let fileURL: URL?

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(fileManager: FileManager = .default) {
        if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.fileURL = docs.appendingPathComponent(Self.filename)
        } else {
            self.fileURL = nil
        }
    }

    func load() -> [ChatMessage] {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try Self.decoder.decode([ChatMessage].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ messages: [ChatMessage]) {
        guard let fileURL else { return }
        let trimmed = Self.truncate(messages)
        do {
            let data = try Self.encoder.encode(trimmed)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            FileHandle.standardError.write(Data("ChatHistoryStore.save failed: \(error)\n".utf8))
        }
    }

    func clear() {
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func truncate(_ messages: [ChatMessage]) -> [ChatMessage] {
        guard messages.count > maxMessages else { return messages }
        return Array(messages.suffix(maxMessages))
    }
}
