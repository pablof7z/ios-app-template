import SwiftUI

// MARK: - Setup step model

/// Represents one step in the agent setup checklist.
private struct SetupStep: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let description: String
    let isDone: Bool
}

// MARK: - Layout constants

private enum SetupCardLayout {
    /// Overall card corner radius.
    static let cardCornerRadius: CGFloat = 16
    /// Padding inside the card.
    static let cardPadding: CGFloat = 16
    /// Gap between icon and text in each step row.
    static let rowHSpacing: CGFloat = 12
    /// Size of the check/circle status badge.
    static let badgeSize: CGFloat = 22
    /// Point size of the icon inside the status badge.
    static let badgeIconSize: CGFloat = 11
    /// Gap between the header icon and the label.
    static let headerHSpacing: CGFloat = 10
    /// Point size of the header icon.
    static let headerIconSize: CGFloat = 18
}

// MARK: - AgentSetupStatusCard

/// A status card shown at the top of AgentSettingsView that guides the user
/// through the two Nostr setup steps: generate identity, then enable networking.
/// When both steps are done it shows a calm "Agent is reachable" confirmation.
struct AgentSetupStatusCard: View {
    let hasNostrKey: Bool
    let nostrEnabled: Bool

    // MARK: - Derived state

    private var allDone: Bool { hasNostrKey && nostrEnabled }

    private var steps: [SetupStep] {
        [
            SetupStep(
                id: 0,
                icon: "key.fill",
                title: "Generate identity",
                description: "Create a Nostr key pair for your agent.",
                isDone: hasNostrKey
            ),
            SetupStep(
                id: 1,
                icon: "antenna.radiowaves.left.and.right",
                title: "Enable Nostr networking",
                description: "Let other agents find and message yours.",
                isDone: nostrEnabled
            ),
        ]
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            header
            Divider()
            stepList
            if !allDone {
                ctaHint
            }
        }
        .padding(SetupCardLayout.cardPadding)
        .glassEffect(
            allDone
                ? .regular.tint(Color.green.opacity(0.10))
                : .regular.tint(Color.indigo.opacity(0.08)),
            in: .rect(cornerRadius: SetupCardLayout.cardCornerRadius)
        )
        .animation(AppTheme.Animation.spring, value: hasNostrKey)
        .animation(AppTheme.Animation.spring, value: nostrEnabled)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: SetupCardLayout.headerHSpacing) {
            Image(systemName: allDone ? "checkmark.shield.fill" : "shield")
                .font(.system(size: SetupCardLayout.headerIconSize, weight: .semibold))
                .foregroundStyle(allDone ? Color.green : Color.indigo)
                .contentTransition(.symbolEffect(.replace))

            Text(allDone ? "Agent is reachable" : "Set up your agent")
                .font(AppTheme.Typography.headline)
                .contentTransition(.opacity)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(allDone ? "Agent is reachable" : "Set up your agent — \(doneCount) of \(steps.count) steps complete")
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            ForEach(steps) { step in
                stepRow(step)
            }
        }
    }

    private func stepRow(_ step: SetupStep) -> some View {
        HStack(alignment: .top, spacing: SetupCardLayout.rowHSpacing) {
            statusBadge(done: step.isDone)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(step.isDone ? .secondary : .primary)
                    .strikethrough(step.isDone, color: .secondary)

                if !step.isDone {
                    Text(step.description)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title): \(step.isDone ? "complete" : "incomplete")")
    }

    private func statusBadge(done: Bool) -> some View {
        ZStack {
            Circle()
                .fill(done ? Color.green.opacity(0.18) : Color(.secondarySystemFill))
                .frame(width: SetupCardLayout.badgeSize, height: SetupCardLayout.badgeSize)
            Image(systemName: done ? "checkmark" : "circle")
                .font(.system(size: SetupCardLayout.badgeIconSize, weight: .bold))
                .foregroundStyle(done ? .green : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityHidden(true)
    }

    private var ctaHint: some View {
        Text(nextStepHint)
            .font(AppTheme.Typography.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private var doneCount: Int { steps.filter(\.isDone).count }

    private var nextStepHint: String {
        if !hasNostrKey {
            return "Tap Identity below to generate a key pair."
        }
        return "Toggle Enabled in the Nostr section below."
    }
}
