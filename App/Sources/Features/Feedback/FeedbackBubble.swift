import SwiftUI

// MARK: - FeedbackBubble

struct FeedbackBubble: View {
    let content: String
    let isFromMe: Bool
    let createdAt: Date
    var onQuoteReply: (() -> Void)? = nil

    private enum Layout {
        static let spacerMinLength: CGFloat = 60
        static let bubbleCornerRadius: CGFloat = 18
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isFromMe { Spacer(minLength: Layout.spacerMinLength) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                if isFromMe {
                    myBubble
                } else {
                    theirBubble
                }

                Text(createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !isFromMe { Spacer(minLength: Layout.spacerMinLength) }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, 2)
    }

    private var myBubble: some View {
        Text(content)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular.tint(.accentColor), in: .rect(cornerRadius: Layout.bubbleCornerRadius))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .contextMenu {
                Button {
                    UIPasteboard.general.string = content
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
    }

    private var theirBubble: some View {
        Text(content)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: Layout.bubbleCornerRadius))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .contextMenu {
                if let onQuoteReply {
                    Button {
                        onQuoteReply()
                    } label: {
                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                    }
                }
            }
    }
}
