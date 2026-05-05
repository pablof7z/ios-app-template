import SwiftUI

struct ItemRow: View {
    let item: Item
    var onToggle: () -> Void
    var onDelete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var didTriggerDelete = false

    private let deleteThreshold: CGFloat = 88
    private let revealThreshold: CGFloat = 56

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteAffordance
            content
                .background(.clear)
                .offset(x: dragOffset)
                .gesture(swipeGesture)
        }
        .clipped()
    }

    private var content: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            Button {
                onToggle()
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isDone ? AnyShapeStyle(Color.green) : AnyShapeStyle(.secondary))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .symbolEffect(.bounce, value: isDone)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Mark as pending" : "Mark as done")

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title.isEmpty ? "Untitled" : item.title)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(isDone ? .secondary : .primary)
                    .strikethrough(isDone, color: .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: AppTheme.Spacing.sm) {
                    if let badge = sourceBadge {
                        badge
                    }
                    if let requester = item.requestedByDisplayName, !requester.isEmpty {
                        Label(requester, systemImage: "person.fill")
                            .font(AppTheme.Typography.caption2)
                            .foregroundStyle(.tertiary)
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                    }
                    Text(relativeDate)
                        .font(AppTheme.Typography.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var deleteAffordance: some View {
        HStack {
            Spacer()
            ZStack {
                Rectangle()
                    .fill(Color.red.opacity(min(1, abs(dragOffset) / deleteThreshold)))
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .opacity(min(1, abs(dragOffset) / revealThreshold))
            }
            .frame(width: max(0, -dragOffset))
        }
        .allowsHitTesting(false)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) else { return }
                if horizontal < 0 {
                    dragOffset = max(horizontal, -160)
                    if !didTriggerDelete && abs(horizontal) > deleteThreshold {
                        didTriggerDelete = true
                        Haptics.selection()
                    }
                    if didTriggerDelete && abs(horizontal) <= deleteThreshold {
                        didTriggerDelete = false
                    }
                } else {
                    dragOffset = min(horizontal * 0.25, 24)
                }
            }
            .onEnded { value in
                let horizontal = value.translation.width
                if horizontal < -deleteThreshold {
                    withAnimation(AppTheme.Animation.springFast) {
                        dragOffset = -500
                    }
                    onDelete()
                } else {
                    withAnimation(AppTheme.Animation.spring) {
                        dragOffset = 0
                    }
                }
                didTriggerDelete = false
            }
    }

    private var isDone: Bool { item.status == .done }

    private var sourceBadge: AnyView? {
        switch item.source {
        case .agent:
            return AnyView(badgeView(label: "Agent", icon: "sparkles", tint: .indigo))
        case .voice:
            return AnyView(badgeView(label: "Voice", icon: "mic.fill", tint: .pink))
        case .manual:
            return nil
        }
    }

    private func badgeView(label: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .semibold))
            Text(label).font(AppTheme.Typography.caption2)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tint.opacity(0.14), in: .capsule)
        .overlay(Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 0.5))
    }

    private var relativeDate: String {
        let interval = Date().timeIntervalSince(item.createdAt)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86_400 { return "\(Int(interval / 3600))h" }
        if interval < 604_800 { return "\(Int(interval / 86_400))d" }
        return item.createdAt.formatted(date: .abbreviated, time: .omitted)
    }
}
