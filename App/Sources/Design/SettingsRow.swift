import SwiftUI

/// Reusable iOS-style settings row for use inside a `List`.
///
/// - Parameters:
///   - icon: SF Symbol name
///   - tint: Fill color of the 29x29 rounded icon badge
///   - title: Primary label
///   - subtitle: Optional secondary label shown below title
///   - value: Optional trailing value text
///   - badge: When > 0, shows an orange `StatBadge` trailing
struct SettingsRow: View {
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var badge: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            iconBadge

            labelStack

            Spacer(minLength: 4)

            trailingContent
        }
    }

    // MARK: - Sub-views

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint)
                .frame(width: 29, height: 29)
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var labelStack: some View {
        if let subtitle {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } else {
            Text(title)
                .font(.body)
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        if badge > 0 {
            StatBadge(value: badge, label: nil, color: .orange)
        } else if let value {
            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
