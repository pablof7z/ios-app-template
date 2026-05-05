import SwiftUI

/// Compact capsule chip used on model rows to indicate capabilities.
/// Color is keyed to the badge text for quick visual scanning.
struct ModelBadge: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            )
    }

    private var foregroundColor: Color {
        switch text {
        case "No JSON":   return .orange
        case "Tools":     return .purple
        case "Reasoning": return .indigo
        case "Vision":    return .teal
        case "Open":      return .green
        default:          return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 6) {
        ModelBadge(text: "No JSON")
        ModelBadge(text: "Tools")
        ModelBadge(text: "Reasoning")
        ModelBadge(text: "Vision")
        ModelBadge(text: "Open")
        ModelBadge(text: "Free")
    }
    .padding()
}
