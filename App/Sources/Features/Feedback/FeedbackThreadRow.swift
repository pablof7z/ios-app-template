import SwiftUI

// MARK: - FeedbackThreadRow

struct FeedbackThreadRow: View {
    let thread: FeedbackThread

    var body: some View {
        HStack(spacing: 12) {
            categoryBadge

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(thread.title ?? thread.content)
                        .lineLimit(1)
                        .font(.body.weight(thread.title != nil ? .semibold : .regular))
                    Spacer()
                    Text(thread.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let summary = thread.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if thread.title != nil, !thread.content.isEmpty {
                    Text(thread.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    if let status = thread.statusLabel, !status.isEmpty {
                        Text(status.uppercased())
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: .capsule)
                            .foregroundStyle(Color.accentColor)
                    }

                    if !thread.replies.isEmpty {
                        Label("\(thread.replies.count)", systemImage: "bubble.left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var categoryBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(thread.category.tint)
                .frame(width: 29, height: 29)
            Image(systemName: thread.category.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}
