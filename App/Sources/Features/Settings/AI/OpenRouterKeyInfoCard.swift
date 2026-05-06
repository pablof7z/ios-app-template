import SwiftUI

/// Compact card displayed after a successful OpenRouter key validation.
/// Shows credit usage, rate-limit tier, and key label.
struct OpenRouterKeyInfoCard: View {

    let info: OpenRouterKeyInfo

    private enum Layout {
        static let cardCornerRadius: CGFloat = 14
        static let rowSpacing: CGFloat = 10
        static let chipCornerRadius: CGFloat = 8
        static let chipHPadding: CGFloat = 8
        static let chipVPadding: CGFloat = 4
        static let barHeight: CGFloat = 6
        static let barCornerRadius: CGFloat = 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            headerRow
            if info.remainingFraction != nil || info.limitDollars != nil {
                creditSection
            }
            tierRow
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
                .foregroundStyle(.green)
                .font(.system(size: 16, weight: .semibold))
            Text("Key validated")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            if let label = info.label, !label.isEmpty {
                Text(label)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var creditSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let remaining = info.remainingLabel {
                Text(remaining)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            } else if info.limitDollars == nil {
                Text(info.usageDollars.map { String(format: "$%.4f used", $0) } ?? "Unlimited credits")
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
            tierChip
            if let requests = info.requestsPerInterval, let interval = info.rateInterval {
                Text("\(requests) req/\(interval)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var tierChip: some View {
        HStack(spacing: 4) {
            Image(systemName: info.isFreeTier ? "gift" : "creditcard")
                .font(.system(size: 10, weight: .semibold))
            Text(info.isFreeTier ? "Free tier" : "Paid")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(info.isFreeTier ? Color.orange : Color.green)
        .padding(.horizontal, Layout.chipHPadding)
        .padding(.vertical, Layout.chipVPadding)
        .background(
            (info.isFreeTier ? Color.orange : Color.green).opacity(0.12),
            in: RoundedRectangle(cornerRadius: Layout.chipCornerRadius, style: .continuous)
        )
    }

    // MARK: - Helpers

    private func barColor(fraction: Double) -> Color {
        if fraction > 0.5 { return .green }
        if fraction > 0.2 { return .orange }
        return .red
    }

    private var accessibilityDescription: String {
        var parts = ["Key validated"]
        if let label = info.label, !label.isEmpty { parts.append(label) }
        if let remaining = info.remainingLabel { parts.append(remaining) }
        parts.append(info.isFreeTier ? "Free tier" : "Paid account")
        if let req = info.requestsPerInterval, let interval = info.rateInterval {
            parts.append("\(req) requests per \(interval)")
        }
        return parts.joined(separator: ", ")
    }
}
