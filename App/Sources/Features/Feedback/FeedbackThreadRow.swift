import SwiftUI

// MARK: - Layout constants

private enum Layout {
    static let rowSpacing: CGFloat = 12
    static let contentSpacing: CGFloat = 4
    static let badgeCornerRadius: CGFloat = 8
    static let badgeSize: CGFloat = 29
    static let badgeIconSize: CGFloat = 14
    static let statusPaddingH: CGFloat = 6
    static let statusPaddingV: CGFloat = 2
    static let metadataSpacing: CGFloat = 6
    static let rowVerticalPadding: CGFloat = 10
}

// MARK: - FeedbackThreadRow

struct FeedbackThreadRow: View {
    let thread: FeedbackThread

    var body: some View {
        HStack(spacing: Layout.rowSpacing) {
            categoryBadge

            VStack(alignment: .leading, spacing: Layout.contentSpacing) {
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

                HStack(spacing: Layout.metadataSpacing) {
                    if let status = thread.statusLabel, !status.isEmpty {
                        Text(status.uppercased())
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, Layout.statusPaddingH)
                            .padding(.vertical, Layout.statusPaddingV)
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
        .padding(.vertical, Layout.rowVerticalPadding)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var categoryBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Layout.badgeCornerRadius)
                .fill(thread.category.tint)
                .frame(width: Layout.badgeSize, height: Layout.badgeSize)
            Image(systemName: thread.category.icon)
                .font(.system(size: Layout.badgeIconSize, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}
