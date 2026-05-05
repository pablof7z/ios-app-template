import SwiftUI

struct HomeView: View {
    @Environment(AppStateStore.self) private var store

    @State private var feedbackWorkflow = FeedbackWorkflow()
    @State private var showFeedback = false
    @State private var showAgentCompose = false
    @State private var agentPrompt = ""

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                hero
                HomeQuickActions(
                    onTalkToAgent: { showAgentCompose = true },
                    onFeedback: { presentFeedback() }
                )
                HomeActivityFeed(entries: recentActivity)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.top, AppTheme.Spacing.sm)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
        .scrollContentBackground(.hidden)
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("Home")
        .sheet(isPresented: $showFeedback) {
            FeedbackView(workflow: feedbackWorkflow)
        }
        .sheet(isPresented: $showAgentCompose) {
            AgentComposePlaceholderSheet(prompt: $agentPrompt)
        }
    }

    private var recentActivity: [AgentActivityEntry] {
        store.state.agentActivity
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(5)
            .map { $0 }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolEffect(.pulse, options: .repeating)
                    .foregroundStyle(.white.opacity(0.95))
                Text("iOS 26 Template")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .textCase(.uppercase)
                    .tracking(1.2)
                Spacer()
            }
            Text("Build delightful agentic apps")
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text("Liquid glass, AI agents, Nostr identity, and shake-to-feedback — wired up and ready.")
                .font(AppTheme.Typography.callout)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: AppTheme.Spacing.sm) {
                heroChip(icon: "brain", label: "\(store.activeMemories.count) memories")
                heroChip(icon: "person.2.fill", label: "\(store.state.friends.count) friends")
                heroChip(icon: "bolt.fill", label: "\(store.state.agentActivity.count) actions")
            }
            .padding(.top, AppTheme.Spacing.xs)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Corner.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Corner.xl, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.xl))
        .appShadow(AppTheme.Shadow.lifted)
    }

    private func heroChip(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption2)
            Text(label).font(AppTheme.Typography.caption)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.18), in: .capsule)
        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
    }

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.36, green: 0.20, blue: 0.84),
                Color(red: 0.14, green: 0.45, blue: 0.92),
                Color(red: 0.05, green: 0.66, blue: 0.84)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.indigo.opacity(0.05),
                Color.blue.opacity(0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func presentFeedback() {
        feedbackWorkflow.draft = ""
        feedbackWorkflow.screenshot = nil
        feedbackWorkflow.annotatedImage = nil
        feedbackWorkflow.phase = .composing
        Haptics.medium()
        showFeedback = true
    }
}

// MARK: - Agent Compose Placeholder Sheet

private struct AgentComposePlaceholderSheet: View {
    @Binding var prompt: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var promptFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Label("Talk to your agent", systemImage: "sparkles")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.secondary)

                Text("Describe what you'd like to do. The agent will reason about your prompt and propose changes you can review and undo.")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ZStack(alignment: .topLeading) {
                    if prompt.isEmpty {
                        Text("e.g. Remind me to pay rent on the 1st")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    }
                    TextEditor(text: $prompt)
                        .focused($promptFocused)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: 140)
                }
                .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))

                Spacer()

                HStack {
                    Spacer()
                    Button {
                        Haptics.success()
                        dismiss()
                    } label: {
                        Label("Send", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(AppTheme.Spacing.lg)
            .navigationTitle("New prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { promptFocused = true }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
