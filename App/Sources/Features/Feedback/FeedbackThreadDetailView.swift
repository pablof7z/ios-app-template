import SwiftUI

// MARK: - FeedbackThreadDetailView

struct FeedbackThreadDetailView: View {
    let thread: FeedbackThread
    let store: FeedbackStore

    @State private var replyDraft = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private var currentThread: FeedbackThread {
        store.threads.first(where: { $0.id == thread.id }) ?? thread
    }

    private var canSend: Bool {
        !replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
        }
        .navigationTitle(currentThread.title ?? currentThread.category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        UIPasteboard.general.string = currentThread.content
                    } label: {
                        Label("Copy text", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("Thread options")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            replyComposer
        }
    }

    // MARK: - Message list

    @ViewBuilder
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if let summary = currentThread.summary, !summary.isEmpty {
                        summaryBanner(summary)
                    }

                    // Root message bubble
                    FeedbackBubble(
                        content: currentThread.content,
                        isFromMe: true,
                        createdAt: currentThread.createdAt
                    )
                    .id("root")

                    // Reply bubbles
                    ForEach(currentThread.replies) { reply in
                        FeedbackBubble(
                            content: reply.content,
                            isFromMe: reply.isFromMe,
                            createdAt: reply.createdAt
                        )
                        .id(reply.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: currentThread.replies.count) { _, _ in
                if let last = currentThread.replies.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func summaryBanner(_ summary: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.callout)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Summary")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 16)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Reply composer

    private var replyComposer: some View {
        VStack(spacing: 6) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Reply\u{2026}", text: $replyDraft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 4)

                Button {
                    Task { await sendReply() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor.opacity(canSend ? 1 : 0.4), in: .circle)
                }
                .accessibilityLabel("Send reply")
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Send reply

    private func sendReply() async {
        isSending = true
        errorMessage = nil
        let trimmed = replyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await store.publishReply(content: trimmed, threadID: thread.id)
            Haptics.success()
            replyDraft = ""
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
        isSending = false
    }
}

// MARK: - FeedbackBubble

struct FeedbackBubble: View {
    let content: String
    let isFromMe: Bool
    let createdAt: Date

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
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    private var myBubble: some View {
        Text(content)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular.tint(.accentColor), in: .rect(cornerRadius: Layout.bubbleCornerRadius))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
    }

    private var theirBubble: some View {
        Text(content)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: Layout.bubbleCornerRadius))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
    }
}
