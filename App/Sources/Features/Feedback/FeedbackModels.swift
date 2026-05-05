import SwiftUI

// MARK: - FeedbackCategory

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug = "Bug"
    case featureRequest = "Feature Request"
    case question = "Question"
    case praise = "Praise"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bug: "ant.fill"
        case .featureRequest: "lightbulb.fill"
        case .question: "questionmark.circle.fill"
        case .praise: "heart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .bug: .red
        case .featureRequest: .blue
        case .question: .purple
        case .praise: .pink
        }
    }
}

// MARK: - FeedbackThread

struct FeedbackThread: Identifiable {
    var id: UUID = UUID()
    var category: FeedbackCategory
    var content: String
    var attachedImage: UIImage?
    var title: String?
    var summary: String?
    var statusLabel: String?
    var replies: [FeedbackReply] = []
    var createdAt: Date = Date()
}

// MARK: - FeedbackReply

struct FeedbackReply: Identifiable {
    var id: UUID = UUID()
    var content: String
    var isFromMe: Bool
    var createdAt: Date = Date()
}
