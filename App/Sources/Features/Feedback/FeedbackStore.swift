import SwiftUI

// MARK: - FeedbackStore

@MainActor
@Observable
final class FeedbackStore {
    var threads: [FeedbackThread] = []
    var isLoading: Bool = false

    func load() async {
        // TODO: Replace with real backend call (Nostr, email, webhook)
        isLoading = true
        try? await Task.sleep(for: .milliseconds(300))
        isLoading = false
    }

    func publishThread(category: FeedbackCategory, content: String, image: UIImage?) async throws {
        // TODO: Replace with real submission
        try await Task.sleep(for: .milliseconds(600))
        let thread = FeedbackThread(category: category, content: content, attachedImage: image)
        threads.insert(thread, at: 0)
    }

    func publishReply(content: String, threadID: UUID) async throws {
        try await Task.sleep(for: .milliseconds(300))
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[idx].replies.append(FeedbackReply(content: content, isFromMe: true))
    }
}
