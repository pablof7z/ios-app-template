import SwiftUI

// MARK: - Constants

/// Stable scroll ID assigned to the typing indicator row.
private let typingIndicatorID = "typing-indicator"

/// Scrollable message transcript with a jump-to-bottom button.
struct AgentChatTranscriptView: View {
    let session: AgentChatSession
    @Binding var scrolledMessageID: AnyHashable?
    let onBatchTap: (UUID) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            let isAtBottom = scrolledMessageID == nil
                || scrolledMessageID == session.messages.last?.id
                || scrolledMessageID == AnyHashable(typingIndicatorID)

            ScrollView {
                messageList
            }
            .scrollPosition(id: $scrolledMessageID, anchor: .bottom)
            .overlay(alignment: .bottomTrailing) {
                if !isAtBottom {
                    jumpToBottomButton(proxy: proxy)
                }
            }
            .onChange(of: session.messages.count) {
                guard let last = session.messages.last else { return }
                withAnimation(AppTheme.Animation.spring) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: session.phase) {
                if case .sending = session.phase {
                    withAnimation(AppTheme.Animation.spring) {
                        proxy.scrollTo(typingIndicatorID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func jumpToBottomButton(proxy: ScrollViewProxy) -> some View {
        Button {
            Haptics.selection()
            withAnimation(AppTheme.Animation.spring) {
                if let lastID = session.messages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        } label: {
            Image(systemName: "chevron.down.circle.fill")
                .font(.system(size: AgentChatLayout.jumpButtonSize))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.indigo)
        }
        .buttonStyle(.plain)
        .padding(AppTheme.Spacing.md)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel("Jump to latest message")
    }

    private var messageList: some View {
        LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            ForEach(Array(session.messages.enumerated()), id: \.element.id) { index, msg in
                let prev = index > 0 ? session.messages[index - 1] : nil
                if shouldShowSeparator(before: msg, previous: prev) {
                    ChatTimeSeparator(date: msg.timestamp)
                        .transition(.opacity)
                }
                AgentChatBubble(message: msg, onOpenBatch: onBatchTap)
                    .id(msg.id)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if case .sending = session.phase {
                AgentTypingIndicator()
                    .id(typingIndicatorID)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.sm)
        .animation(AppTheme.Animation.spring, value: session.messages.count)
        .animation(AppTheme.Animation.spring, value: session.phase)
    }

    // MARK: - Timestamp separator logic

    /// Returns true when a time-gap separator should be shown before `msg`.
    /// Separators appear before the first conversational message in a session,
    /// and whenever 15+ minutes have elapsed since the previous message.
    /// Tool-batch and error rows (system events) never get separators.
    private func shouldShowSeparator(before msg: ChatMessage, previous prev: ChatMessage?) -> Bool {
        switch msg.role {
        case .user, .assistant: break
        case .toolBatch, .error: return false
        }
        guard let prev else { return true }
        switch prev.role {
        case .user, .assistant:
            return msg.timestamp.timeIntervalSince(prev.timestamp) >= AgentChatLayout.timeSeparatorThreshold
        case .toolBatch, .error:
            return false
        }
    }
}
