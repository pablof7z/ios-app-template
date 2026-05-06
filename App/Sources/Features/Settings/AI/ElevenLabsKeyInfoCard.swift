import SwiftUI

/// Compact card displayed after a successful ElevenLabs key validation.
/// Shows character quota and subscription tier.
struct ElevenLabsKeyInfoCard: View {

    let info: ElevenLabsKeyInfo

    private enum Layout {
        static let cardCornerRadius: CGFloat = 14
        static let rowSpacing: CGFloat = 10
        static let chipCornerRadius: CGFloat = 8
        static let chipHPadding: CGFloat = 8
        static let chipVPadding: CGFloat = 4
        static let barHeight: CGFloat = 6
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            headerRow
            if info.remainingFraction != nil || info.remainingLabel != nil {
                quotaSection
            }
            if info.tier != nil {
                tierRow
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Sub-views

    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(AppTheme.Brand.elevenLabsTint)
                .font(.system(size: 16, weight: .semibold))
            Text("Key validated")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    @ViewBuilder
    private var quotaSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = info.remainingLabel {
                Text(label)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            if let fraction = info.remainingFraction {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemFill))
                            .frame(height: Layout.barHeight)
                        Capsule()
                            .fill(barColor(fraction: fraction))
                            .frame(width: geo.size.width * fraction, height: Layout.barHeight)
                    }
                }
                .frame(height: Layout.barHeight)
            }
        }
    }

    private var tierRow: some View {
        HStack(spacing: 8) {
            if let tier = info.tier {
                tierChip(tier: tier)
            }
            Spacer()
        }
    }

    private func tierChip(tier: String) -> some View {
        let isFreeTier = tier.lowercased() == "free"
        return HStack(spacing: 4) {
            Image(systemName: isFreeTier ? "gift" : "creditcard")
                .font(.system(size: 10, weight: .semibold))
            Text(tier.capitalized)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(isFreeTier ? Color.orange : AppTheme.Brand.elevenLabsTint)
        .padding(.horizontal, Layout.chipHPadding)
        .padding(.vertical, Layout.chipVPadding)
        .background(
            (isFreeTier ? Color.orange : AppTheme.Brand.elevenLabsTint).opacity(0.12),
            in: RoundedRectangle(cornerRadius: Layout.chipCornerRadius, style: .continuous)
        )
    }

    // MARK: - Helpers

    private func barColor(fraction: Double) -> Color {
        if fraction > 0.5 { return AppTheme.Brand.elevenLabsTint }
        if fraction > 0.2 { return .orange }
        return .red
    }

    private var accessibilityDescription: String {
        var parts = ["Key validated"]
        if let label = info.remainingLabel { parts.append(label) }
        if let tier = info.tier { parts.append("Plan: \(tier)") }
        return parts.joined(separator: ", ")
    }
}
