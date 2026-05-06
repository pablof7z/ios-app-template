import SwiftUI

// MARK: - Layout constants

private enum Layout {
    static let avatarSize: CGFloat = 30
    static let avatarIconSize: CGFloat = 14
    static let bubbleCornerRadius: CGFloat = 18
    static let bubblePaddingH: CGFloat = 14
    static let bubblePaddingV: CGFloat = 10
    /// Corner radius for tool-batch and suggestion chip glass pills.
    static let pillCornerRadius: CGFloat = 14
    /// Horizontal padding inside tool-batch pill.
    static let batchPaddingH: CGFloat = 12
    /// Vertical padding inside tool-batch pill.
    static let batchPaddingV: CGFloat = 8
    /// Icon size (point size) for the tool-batch wand icon.
    static let batchIconSize: CGFloat = 13
    /// Leading indent of the tool-batch row (aligns with assistant bubble text).
    static let batchLeadingInset: CGFloat = 44
    /// Trailing inset of the tool-batch row.
    static let batchTrailingInset: CGFloat = 24
    /// Dot size in the typing indicator.
    static let typingDotSize: CGFloat = 7
    /// Spacing between typing indicator dots.
    static let typingDotSpacing: CGFloat = 6
    /// Corner radius for the typing indicator glass pill.
    static let typingCornerRadius: CGFloat = 18
    /// Horizontal padding inside the typing indicator pill.
    static let typingPaddingH: CGFloat = 14
    /// Vertical padding inside the typing indicator pill.
    static let typingPaddingV: CGFloat = 12
}

// MARK: - Avatar

private struct AgentAvatarView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.indigo, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: Layout.avatarSize, height: Layout.avatarSize)
            Image(systemName: "sparkles")
                .font(.system(size: Layout.avatarIconSize, weight: .semibold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
        .accessibilityHidden(true)
        .appShadow(AppTheme.Shadow.subtle)
    }
}

// MARK: - Chat Bubble

/// Renders a single chat message in the agent conversation, adapting its
/// appearance based on the message role (user, assistant, tool batch, or error).
struct AgentChatBubble: View {
    let message: ChatMessage
    var onOpenBatch: (UUID) -> Void = { _ in }

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            assistantBubble
        case .toolBatch(let batchID, let count):
            toolBatchRow(batchID: batchID, count: count)
        case .error:
            errorBubble
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 40)
            Text(message.text)
                .font(AppTheme.Typography.body)
                .foregroundStyle(.white)
                .padding(.horizontal, Layout.bubblePaddingH)
                .padding(.vertical, Layout.bubblePaddingV)
                .background(AppTheme.Gradients.agentAccent, in: .rect(cornerRadius: Layout.bubbleCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                )
                .appShadow(AppTheme.Shadow.subtle)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.text
                        Haptics.success()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
        }
    }

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            AgentAvatarView()
            Text(message.text)
                .font(AppTheme.Typography.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, Layout.bubblePaddingH)
                .padding(.vertical, Layout.bubblePaddingV)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: Layout.bubbleCornerRadius))
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.text
                        Haptics.success()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            Spacer(minLength: 0)
        }
    }

    private func toolBatchRow(batchID: UUID, count: Int) -> some View {
        Button {
            Haptics.selection()
            onOpenBatch(batchID)
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: Layout.batchIconSize, weight: .semibold))
                    .foregroundStyle(.indigo)
                    .accessibilityHidden(true)
                Text(count == 1 ? "Agent ran 1 action" : "Agent ran \(count) actions")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Layout.batchPaddingH)
            .padding(.vertical, Layout.batchPaddingV)
            .glassEffect(
                .regular.tint(.indigo.opacity(0.10)).interactive(),
                in: .rect(cornerRadius: Layout.pillCornerRadius)
            )
        }
        .buttonStyle(.plain)
        .padding(.leading, Layout.batchLeadingInset)
        .padding(.trailing, Layout.batchTrailingInset)
    }

    private var errorBubble: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .padding(.top, 8)
                .accessibilityHidden(true)
            Text(message.text)
                .font(AppTheme.Typography.callout)
                .foregroundStyle(.primary)
                .padding(.horizontal, Layout.bubblePaddingH)
                .padding(.vertical, Layout.bubblePaddingV)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular.tint(.orange.opacity(0.12)), in: .rect(cornerRadius: Layout.bubbleCornerRadius))
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.text
                        Haptics.success()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            Spacer(minLength: 0)
        }
    }

}

// MARK: - Time Separator

/// Centered timestamp label shown between message groups separated by ≥ 15 minutes.
/// Uses a human-friendly format: "Today 2:34 PM", "Yesterday 9:15 AM",
/// "Mon 2:34 PM" (within the last week), or "Mar 5, 2:34 PM" (older).
struct ChatTimeSeparator: View {
    let date: Date

    var body: some View {
        Text(formattedDate)
            .font(AppTheme.Typography.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, AppTheme.Spacing.xs)
            .accessibilityLabel(accessibilityLabel)
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()
        let timeStr = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) {
            return "Today \(timeStr)"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday \(timeStr)"
        } else if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 7 {
            let dayName = date.formatted(.dateTime.weekday(.wide))
            return "\(dayName) \(timeStr)"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        }
    }

    private var accessibilityLabel: String {
        date.formatted(date: .complete, time: .shortened)
    }
}

// MARK: - Typing Indicator

/// Animated three-dot indicator shown while the agent is generating a response.
struct AgentTypingIndicator: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            AgentAvatarView()
                .symbolEffect(.pulse, options: .repeating)

            HStack(spacing: Layout.typingDotSpacing) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.secondary)
                        .frame(width: Layout.typingDotSize, height: Layout.typingDotSize)
                        .opacity(phase == i ? 1.0 : 0.35)
                        .scaleEffect(phase == i ? 1.15 : 0.9)
                        .animation(AppTheme.Animation.easeInOut, value: phase)
                }
            }
            .padding(.horizontal, Layout.typingPaddingH)
            .padding(.vertical, Layout.typingPaddingV)
            .glassEffect(.regular, in: .rect(cornerRadius: Layout.typingCornerRadius))
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: AppTheme.Timing.typingDotStep)
                    phase = (phase + 1) % 3
                }
            }
            Spacer(minLength: 0)
        }
    }
}
