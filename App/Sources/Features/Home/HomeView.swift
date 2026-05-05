import SwiftUI

struct HomeView: View {
    @Environment(AppStateStore.self) private var store

    @State private var feedbackWorkflow = FeedbackWorkflow()
    @State private var showFeedback = false
    @State private var showAgentChat = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                hero
                HomeQuickActions(
                    onTalkToAgent: { showAgentChat = true },
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
        .sheet(isPresented: $showAgentChat) {
            AgentChatView()
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
