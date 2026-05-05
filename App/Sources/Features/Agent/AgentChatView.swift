import SwiftUI

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
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.indigo)
                .accessibilityHidden(true)
            Text("Continuing from your previous session")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Button {
                withAnimation(AppTheme.Animation.spring) { bannerDismissed = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss banner")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(.indigo.opacity(0.10)), in: .rect(cornerRadius: 12))
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
    }

    private func transcript(session: AgentChatSession) -> some View {
        ScrollViewReader { proxy in
            let isAtBottom = scrolledMessageID == nil
                || scrolledMessageID == session.messages.last?.id
                || scrolledMessageID == AnyHashable("typing-indicator")

            ScrollView {
                messageList(session: session)
            }
            .scrollPosition(id: $scrolledMessageID, anchor: .bottom)
            .overlay(alignment: .bottomTrailing) {
                if !isAtBottom {
                    Button {
                        Haptics.selection()
                        withAnimation(AppTheme.Animation.spring) {
                            if let lastID = session.messages.last?.id {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 30))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.indigo)
                    }
                    .buttonStyle(.plain)
                    .padding(AppTheme.Spacing.md)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Jump to latest message")
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
                        proxy.scrollTo("typing-indicator", anchor: .bottom)
                    }
                }
            }
        }
    }

    private func messageList(session: AgentChatSession) -> some View {
        LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            ForEach(session.messages) { msg in
                AgentChatBubble(message: msg) { batchID in
                    presentedBatch = batchID
                }
                .id(msg.id)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if case .sending = session.phase {
                AgentTypingIndicator()
                    .id("typing-indicator")
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.sm)
        .animation(AppTheme.Animation.spring, value: session.messages.count)
        .animation(AppTheme.Animation.spring, value: session.phase)
    }

    @ViewBuilder
    private var emptyState: some View {
        if showSettingsHint {
            disconnectedState
        } else {
            welcomeState
        }
    }

    private var welcomeState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(LinearGradient(
                    colors: [.indigo, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .symbolEffect(.pulse, options: .repeating)
            Text("Ask your agent anything")
                .font(AppTheme.Typography.title)
            Text("Add tasks, save notes, or remember things. The agent uses tools and you can undo any change.")
                .font(AppTheme.Typography.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppTheme.Spacing.lg)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                suggestionChip("Remind me to pay rent on the 1st")
                suggestionChip("Save a note: brainstorm app names")
                suggestionChip("Remember I prefer dark roast")
            }
            .padding(.top, AppTheme.Spacing.sm)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.Spacing.lg)
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            Haptics.selection()
            draft = text
            inputFocused = true
        } label: {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.caption)
                    .foregroundStyle(.indigo)
                    .accessibilityHidden(true)
                Text(text)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                .regular.tint(.indigo.opacity(0.08)).interactive(),
                in: .rect(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
    }

    private var disconnectedState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Spacer()
            Image(systemName: "key.slash.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("Connect OpenRouter to chat")
                .font(AppTheme.Typography.title)
                .multilineTextAlignment(.center)
            Text("The agent runs on a model of your choice via OpenRouter. Add your key in Settings to begin.")
                .font(AppTheme.Typography.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppTheme.Spacing.lg)
            NavigationLink {
                OpenRouterSettingsView()
            } label: {
                Label("Open AI Settings", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.Spacing.lg)
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
                    .font(.caption)
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
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
                .disabled(showSettingsHint)

            Button {
                sendCurrentDraft()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
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
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.indigo.opacity(0.05),
                Color.blue.opacity(0.04),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct IdentifiedBatch: Identifiable {
    let id: UUID
}
