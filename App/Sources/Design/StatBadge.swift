import SwiftUI

/// Small glass capsule badge for counts and short labels.
/// Use inside GlassEffectContainer when placing alongside other glass views.
struct StatBadge: View {
    let value: Int
    var label: String? = nil
    var color: Color = .accentColor

    var body: some View {
        HStack(spacing: 2) {
            Text("\(value)")
                .font(.caption.weight(.bold).monospacedDigit())
            if let label {
                Text(label)
                    .font(.caption2.weight(.medium))
            }
        }
        .padding(.horizontal, (value < 10 && label == nil) ? 6 : 8)
        .padding(.vertical, 3)
        .foregroundStyle(color)
        .glassEffect(.regular.tint(color), in: .capsule)
    }
}

// MARK: - Convenience factory methods

extension StatBadge {
    static func tasks(_ count: Int, color: Color = .accentColor) -> StatBadge {
        StatBadge(value: count, label: count == 1 ? "task" : "tasks", color: color)
    }

    static func count(_ count: Int, color: Color = .secondary) -> StatBadge {
        StatBadge(value: count, color: color)
    }

    static func memories(_ count: Int) -> StatBadge {
        StatBadge(value: count, label: count == 1 ? "memory" : "memories", color: .purple)
    }
}
