import SwiftUI

struct HomeQuickActions: View {
    @Environment(AppStateStore.self) private var store

    var onTalkToAgent: () -> Void
    var onFeedback: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("Quick actions")
                    .font(AppTheme.Typography.headline)
                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.xs)

            GlassEffectContainer(spacing: AppTheme.Spacing.md) {
                LazyVGrid(columns: gridColumns, spacing: AppTheme.Spacing.md) {
                    Button {
                        Haptics.selection()
                        onTalkToAgent()
                    } label: {
                        QuickActionCardContent(
                            icon: "sparkles",
                            title: "Talk to Agent",
                            subtitle: "Compose a prompt",
                            tint: .indigo
                        )
                    }
                    .buttonStyle(QuickActionButtonStyle(tint: .indigo))

                    NavigationLink {
                        AgentMemoriesView()
                            .navigationTitle("Memories")
                    } label: {
                        QuickActionCardContent(
                            icon: "brain",
                            title: "Memories",
                            subtitle: "\(store.activeMemories.count) saved",
                            tint: .purple
                        )
                    }
                    .buttonStyle(QuickActionButtonStyle(tint: .purple))
                    .simultaneousGesture(TapGesture().onEnded { Haptics.selection() })

                    Button {
                        Haptics.medium()
                        onFeedback()
                    } label: {
                        QuickActionCardContent(
                            icon: "exclamationmark.bubble.fill",
                            title: "Feedback",
                            subtitle: "Or shake your device",
                            tint: .pink
                        )
                    }
                    .buttonStyle(QuickActionButtonStyle(tint: .pink))

                    NavigationLink {
                        SettingsView()
                    } label: {
                        QuickActionCardContent(
                            icon: "slider.horizontal.3",
                            title: "Settings",
                            subtitle: "Identity, AI, data",
                            tint: .teal
                        )
                    }
                    .buttonStyle(QuickActionButtonStyle(tint: .teal))
                    .simultaneousGesture(TapGesture().onEnded { Haptics.selection() })
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: AppTheme.Spacing.md),
            GridItem(.flexible(), spacing: AppTheme.Spacing.md)
        ]
    }
}

// MARK: - Quick action card content

private struct QuickActionCardContent: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .padding(AppTheme.Spacing.md)
    }
}

// MARK: - Glass button style for quick action cards

private struct QuickActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassEffect(
                .regular.tint(tint.opacity(0.10)).interactive(),
                in: .rect(cornerRadius: AppTheme.Corner.lg)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(AppTheme.Animation.springFast, value: configuration.isPressed)
    }
}
