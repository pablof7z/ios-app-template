import SwiftUI

struct AgentChatBubble: View {
    let message: ChatMessage
    var onOpenBatch: (UUID) -> Void = { _ in }

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            assistantBubble
        case .toolBatch(let batchID, let count):
            toolBatchRow(batchID: batchID, count: count)
        case .error:
            errorBubble
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 40)
            Text(message.text)
                .font(AppTheme.Typography.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(userGradient, in: .rect(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                )
                .appShadow(AppTheme.Shadow.subtle)
        }
    }

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            assistantAvatar
            Text(message.text)
                .font(AppTheme.Typography.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
            Spacer(minLength: 0)
        }
    }

    private func toolBatchRow(batchID: UUID, count: Int) -> some View {
        Button {
            Haptics.selection()
            onOpenBatch(batchID)
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.indigo)
                Text(count == 1 ? "Agent ran 1 action" : "Agent ran \(count) actions")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(
                .regular.tint(.indigo.opacity(0.10)).interactive(),
                in: .rect(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
        .padding(.leading, 44)
        .padding(.trailing, 24)
    }

    private var errorBubble: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .padding(.top, 8)
            Text(message.text)
                .font(AppTheme.Typography.callout)
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular.tint(.orange.opacity(0.12)), in: .rect(cornerRadius: 18))
            Spacer(minLength: 0)
        }
    }

    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.indigo, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 30, height: 30)
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .appShadow(AppTheme.Shadow.subtle)
    }

    private var userGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.36, green: 0.20, blue: 0.84),
                Color(red: 0.14, green: 0.45, blue: 0.92),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct AgentTypingIndicator: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.indigo, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 30, height: 30)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
            }

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 7, height: 7)
                        .opacity(phase == i ? 1.0 : 0.35)
                        .scaleEffect(phase == i ? 1.15 : 0.9)
                        .animation(.easeInOut(duration: 0.3), value: phase)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    phase = (phase + 1) % 3
                }
            }
            Spacer(minLength: 0)
        }
    }
}
