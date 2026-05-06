import SwiftUI

// MARK: - Layout constants

private enum DetailLayout {
    static let statusPaddingH: CGFloat = 8
    static let statusPaddingV: CGFloat = 3
    static let imageCornerRadius: CGFloat = 14
    static let imageMaxHeight: CGFloat = 240
    /// Uniform padding around the close button in the fullscreen image overlay.
    static let closeButtonPadding: CGFloat = 20
}

// MARK: - FeedbackThreadDetailView

struct FeedbackThreadDetailView: View {
    let thread: FeedbackThread
    let store: FeedbackStore

    @State private var replyDraft = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var imageFullscreen = false
    @FocusState private var composerFocused: Bool

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
                HStack(spacing: 4) {
                    if let status = currentThread.statusLabel, !status.isEmpty {
                        statusBadge(status)
                    }
                    Menu {
                        Button {
                            UIPasteboard.general.string = currentThread.content
                            Haptics.selection()
                        } label: {
                            Label("Copy text", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityLabel("Thread options")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            replyComposer
        }
        .fullScreenCover(isPresented: $imageFullscreen) {
            if let image = currentThread.attachedImage {
                imageViewer(image)
            }
        }
    }

    // MARK: - Status badge

    private func statusBadge(_ status: String) -> some View {
        Text(status.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, DetailLayout.statusPaddingH)
            .padding(.vertical, DetailLayout.statusPaddingV)
            .background(Color.accentColor.opacity(0.15), in: .capsule)
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("Status: \(status)")
    }

    // MARK: - Full-screen image viewer

    private func imageViewer(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button {
                imageFullscreen = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .padding(DetailLayout.closeButtonPadding)
            }
            .accessibilityLabel("Close image")
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

                    // Attached screenshot (if any)
                    if let image = currentThread.attachedImage {
                        attachedImageBubble(image)
                    }

                    // Reply bubbles
                    ForEach(currentThread.replies) { reply in
                        FeedbackBubble(
                            content: reply.content,
                            isFromMe: reply.isFromMe,
                            createdAt: reply.createdAt,
                            onQuoteReply: reply.isFromMe ? nil : {
                                quoteReply(reply.content)
                            }
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

    // MARK: - Attached image bubble

    private func attachedImageBubble(_ image: UIImage) -> some View {
        HStack {
            Spacer(minLength: 60)
            Button {
                Haptics.selection()
                imageFullscreen = true
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: DetailLayout.imageMaxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: DetailLayout.imageCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: DetailLayout.imageCornerRadius)
                            .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Attached screenshot — tap to expand")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func summaryBanner(_ summary: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(AppTheme.Typography.callout)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Summary")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(summary)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.primary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: AppTheme.Corner.lg)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Reply composer

    private var replyComposer: some View {
        VStack(spacing: 6) {
            if let errorMessage {
                Text(errorMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Reply\u{2026}", text: $replyDraft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 4)
                    .focused($composerFocused)

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

    // MARK: - Quote reply

    private func quoteReply(_ content: String) {
        Haptics.selection()
        let quoted = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "> \($0)" }
            .joined(separator: "\n")
        let prefix = quoted + "\n\n"
        if replyDraft.isEmpty {
            replyDraft = prefix
        } else {
            replyDraft = prefix + replyDraft
        }
        composerFocused = true
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
