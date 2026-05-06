import SwiftUI

// MARK: - Layout constants

enum AgentChatLayout {
    /// Minimum elapsed time (seconds) between two messages before a time separator is shown.
    static let timeSeparatorThreshold: TimeInterval = 15 * 60
    /// Point size of the jump-to-bottom chevron button.
    static let jumpButtonSize: CGFloat = 30
    /// Point size of the icon inside the resume-session banner's dismiss button.
    static let bannerCloseIconSize: CGFloat = 11
    /// Tap-target dimension of the resume-session banner dismiss button.
    static let bannerCloseFrameSize: CGFloat = 22
    /// Point size of the icon inside the resume-session banner.
    static let bannerIconSize: CGFloat = 14
    /// Horizontal padding inside the input text field glass pill.
    static let inputFieldPaddingH: CGFloat = 14
    /// Vertical padding inside the input text field glass pill.
    static let inputFieldPaddingV: CGFloat = 10
    /// Corner radius of the input text field glass pill.
    static let inputFieldCornerRadius: CGFloat = 22
    /// Diameter of the send button.
    static let sendButtonSize: CGFloat = 38
    /// Point size of the send-button arrow icon.
    static let sendButtonIconSize: CGFloat = 17
    /// Corner radius for suggestion chips and tool-batch pills in the welcome state.
    static let chipCornerRadius: CGFloat = 14
    /// Corner radius for the resume-session banner glass pill.
    static let bannerCornerRadius: CGFloat = 12
}

/// Full-screen chat interface for the AI agent, presented as a sheet.
struct AgentChatView: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var session: AgentChatSession?
    @State private var draft: String = ""
    @State private var presentedBatch: UUID?
    @State private var showSettingsHint = false
    @State private var bannerDismissed = false
    @State private var didSendInSession = false
    @State private var showClearConfirm = false
    @State private var scrolledMessageID: AnyHashable? = nil
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                content
            }
            .navigationTitle("Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .alert("Clear conversation?", isPresented: $showClearConfirm, actions: clearAlertActions, message: clearAlertMessage)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if session == nil { session = AgentChatSession(store: store) }
            showSettingsHint = !OpenRouterCredentialStore.hasAPIKey()
            inputFocused = OpenRouterCredentialStore.hasAPIKey()
        }
        .sheet(item: Binding(
            get: { presentedBatch.map(IdentifiedBatch.init) },
            set: { presentedBatch = $0?.id }
        )) { batch in
            AgentActivitySheet(batchID: batch.id)
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
            if let session, !session.messages.isEmpty {
                Button {
                    Haptics.selection()
                    showClearConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Clear conversation")
            }
        }
    }

    @ViewBuilder
    private func clearAlertActions() -> some View {
        Button("Clear", role: .destructive) {
            session?.clearHistory()
            bannerDismissed = false
            didSendInSession = false
            Haptics.success()
        }
        Button("Cancel", role: .cancel) {}
    }

    private func clearAlertMessage() -> some View {
        Text("This permanently deletes the chat history on this device.")
    }

    @ViewBuilder
    private var content: some View {
        if let session {
            VStack(spacing: 0) {
                if shouldShowResumeBanner(session: session) {
                    resumeBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if session.messages.isEmpty {
                    emptyState
                } else {
                    transcript(session: session)
                }
                composer(session: session)
            }
            .animation(AppTheme.Animation.spring, value: shouldShowResumeBanner(session: session))
        } else {
            ProgressView()
        }
    }

    private func shouldShowResumeBanner(session: AgentChatSession) -> Bool {
        session.loadedFromHistory && !bannerDismissed && !didSendInSession
    }

    private var resumeBanner: some View {
        AgentChatResumeBanner(isDismissed: $bannerDismissed)
    }

    private func transcript(session: AgentChatSession) -> some View {
        AgentChatTranscriptView(
            session: session,
            scrolledMessageID: $scrolledMessageID,
            onBatchTap: { presentedBatch = $0 }
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        if showSettingsHint {
            AgentChatDisconnectedView()
        } else {
            AgentChatWelcomeView(draft: $draft, inputFocused: $inputFocused)
        }
    }

    private func composer(session: AgentChatSession) -> some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            errorBanner(for: session.phase)
            inputRow(session: session)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func errorBanner(for phase: AgentChatSession.Phase) -> some View {
        if case .failed(let msg) = phase {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(AppTheme.Typography.caption)
                    .accessibilityHidden(true)
                Text(msg)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    private func inputRow(session: AgentChatSession) -> some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
            TextField("Message your agent…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .lineLimit(1...5)
                .padding(.horizontal, AgentChatLayout.inputFieldPaddingH)
                .padding(.vertical, AgentChatLayout.inputFieldPaddingV)
                .glassEffect(.regular, in: .rect(cornerRadius: AgentChatLayout.inputFieldCornerRadius))
                .disabled(showSettingsHint)

            Button {
                sendCurrentDraft()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: AgentChatLayout.sendButtonIconSize, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: AgentChatLayout.sendButtonSize, height: AgentChatLayout.sendButtonSize)
                    .background(AppTheme.Gradients.agentAccent, in: .circle)
                    .opacity(canSend(session: session) ? 1.0 : 0.4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Send message")
            .disabled(!canSend(session: session))
            .animation(AppTheme.Animation.springFast, value: canSend(session: session))
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private func canSend(session: AgentChatSession) -> Bool {
        guard !showSettingsHint else { return false }
        guard session.canSend else { return false }
        return !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendCurrentDraft() {
        guard let session, canSend(session: session) else { return }
        let text = draft
        draft = ""
        didSendInSession = true
        Haptics.light()
        Task {
            await session.send(text)
            if case .failed = session.phase {
                Haptics.error()
            } else {
                Haptics.success()
            }
        }
    }

    private var background: LinearGradient {
        AppTheme.Gradients.agentChatBackground
    }
}

private struct IdentifiedBatch: Identifiable {
    let id: UUID
}

