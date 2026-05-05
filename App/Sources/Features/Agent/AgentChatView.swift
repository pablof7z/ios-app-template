import SwiftUI

struct AgentChatView: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var session: AgentChatSession?
    @State private var draft: String = ""
    @State private var presentedBatch: UUID?
    @State private var showSettingsHint = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                content
            }
            .navigationTitle("Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
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

    @ViewBuilder
    private var content: some View {
        if let session {
            VStack(spacing: 0) {
                if session.messages.isEmpty {
                    emptyState
                } else {
                    transcript(session: session)
                }
                composer(session: session)
            }
        } else {
            ProgressView()
        }
    }

    private func transcript(session: AgentChatSession) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
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
            if case .failed(let msg) = session.phase {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(msg)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
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
        .background(.ultraThinMaterial)
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
