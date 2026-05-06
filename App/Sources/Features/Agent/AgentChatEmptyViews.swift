import SwiftUI

// MARK: - Resume session banner

/// Banner shown at the top of the chat when the user is continuing a previous session.
struct AgentChatResumeBanner: View {
    @Binding var isDismissed: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: AgentChatLayout.bannerIconSize, weight: .semibold))
                .foregroundStyle(.indigo)
                .accessibilityHidden(true)
            Text("Continuing from your previous session")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Button {
                withAnimation(AppTheme.Animation.spring) { isDismissed = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: AgentChatLayout.bannerCloseIconSize, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: AgentChatLayout.bannerCloseFrameSize,
                        height: AgentChatLayout.bannerCloseFrameSize
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss banner")
        }
        .padding(.horizontal, AgentChatLayout.inputFieldPaddingH)
        .padding(.vertical, AgentChatLayout.inputFieldPaddingV)
        .glassEffect(
            .regular.tint(.indigo.opacity(0.10)),
            in: .rect(cornerRadius: AgentChatLayout.bannerCornerRadius)
        )
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
    }
}

// MARK: - Welcome state

/// Empty-state view when the agent is connected but no messages have been sent yet.
struct AgentChatWelcomeView: View {
    @Binding var draft: String
    var inputFocused: FocusState<Bool>.Binding

    var body: some View {
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
            inputFocused.wrappedValue = true
        } label: {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.indigo)
                    .accessibilityHidden(true)
                Text(text)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AgentChatLayout.inputFieldPaddingH)
            .padding(.vertical, AgentChatLayout.inputFieldPaddingV)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                .regular.tint(.indigo.opacity(0.08)).interactive(),
                in: .rect(cornerRadius: AgentChatLayout.chipCornerRadius)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Disconnected state

/// Empty-state view shown when OpenRouter is not yet connected.
struct AgentChatDisconnectedView: View {
    var body: some View {
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
}
