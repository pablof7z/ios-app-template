import SwiftUI

// MARK: - FeedbackStore

@MainActor
@Observable
final class FeedbackStore {
    var threads: [FeedbackThread] = []
    var isLoading: Bool = false

    private static var persistenceURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("feedback_threads.json")
    }

    func load() async {
        isLoading = true
        threads = (try? loadFromDisk()) ?? []
        isLoading = false
    }

    @discardableResult
    func publishThread(category: FeedbackCategory, content: String, image: UIImage?) async throws -> FeedbackThread {
        try await Task.sleep(for: .milliseconds(600))
        let thread = FeedbackThread(category: category, content: content, attachedImage: image)
        threads.insert(thread, at: 0)
        try? saveToDisk()
        return thread
    }

    func publishReply(content: String, threadID: UUID) async throws {
        try await Task.sleep(for: .milliseconds(300))
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[idx].replies.append(FeedbackReply(content: content, isFromMe: true))
        try? saveToDisk()
    }

    // MARK: - Private persistence helpers

    private func saveToDisk() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(threads)
        try data.write(to: Self.persistenceURL, options: .atomic)
    }

    private func loadFromDisk() throws -> [FeedbackThread] {
        let data = try Data(contentsOf: Self.persistenceURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([FeedbackThread].self, from: data)
    }
}
