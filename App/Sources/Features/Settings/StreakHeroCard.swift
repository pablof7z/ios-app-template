import SwiftUI

// MARK: - StreakHeroCard

/// A prominent hero card that displays the current streak with a large animated flame.
/// The flame size and background tint escalate with the streak length to reward consistency.
/// Milestone badges appear at 7, 30, and 100-day thresholds.
struct StreakHeroCard: View {

    enum Layout {
        static let flameSizeBase: CGFloat    = 52
        static let flameSizeMax: CGFloat     = 72
        static let numberFontSize: CGFloat   = 64
        static let borderOpacity: Double     = 0.20
        static let borderLineWidth: CGFloat  = 1
        static let pulseScale: CGFloat       = 1.06
        static let pulseDuration: Double     = 1.4
        /// Denominator used to normalise the flame-size ramp (reaches max at this streak length).
        static let flameSizeRampDays: CGFloat = 14
        /// Fill opacity of the milestone badge capsule background.
        static let badgeFillOpacity: Double = 0.12
    }

    let currentStreak: Int
    let longestStreak: Int

    @State private var isPulsing = false

    private var tint: Color {
        switch currentStreak {
        case 0:       return .secondary
        case 1...2:   return .orange
        case 3...6:   return .yellow
        default:      return .red
        }
    }

    private var flameSize: CGFloat {
        guard currentStreak > 0 else { return Layout.flameSizeBase }
        let factor = min(CGFloat(currentStreak) / Layout.flameSizeRampDays, 1.0)
        return Layout.flameSizeBase + factor * (Layout.flameSizeMax - Layout.flameSizeBase)
    }

    /// Milestone badge text shown when the streak hits a notable threshold.
    private var milestoneBadge: String? {
        switch currentStreak {
        case 100...: return "Century streak"
        case 30...:  return "On Fire"
        case 7...:   return "Week streak"
        default:     return nil
        }
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            mainRow
            if let badge = milestoneBadge {
                milestoneBadgeRow(badge)
            }
            if longestStreak > currentStreak {
                personalBestRow
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Corner.lg, style: .continuous))
        .appShadow(AppTheme.Shadow.card)
        .onAppear { if currentStreak > 0 { isPulsing = true } }
        .onChange(of: currentStreak) { _, new in isPulsing = new > 0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current streak: \(currentStreak) day\(currentStreak == 1 ? "" : "s")")
    }

    // MARK: - Sub-views

    private var mainRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            Image(systemName: "flame.fill")
                .font(.system(size: flameSize, weight: .semibold))
                .foregroundStyle(currentStreak > 0 ? tint : Color.secondary)
                .scaleEffect(isPulsing ? Layout.pulseScale : 1.0)
                .animation(
                    currentStreak > 0
                        ? .easeInOut(duration: Layout.pulseDuration).repeatForever(autoreverses: true)
                        : .default,
                    value: isPulsing
                )

            VStack(alignment: .leading, spacing: 0) {
                Text("\(currentStreak)")
                    .font(.system(size: Layout.numberFontSize, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text(currentStreak == 1 ? "day streak" : "days streak")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private func milestoneBadgeRow(_ badge: String) -> some View {
        HStack {
            Image(systemName: "flame.fill")
                .font(AppTheme.Typography.caption2)
                .foregroundStyle(tint)
            Text(badge)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(tint)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(Capsule().fill(tint.opacity(Layout.badgeFillOpacity)))
    }

    private var personalBestRow: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .font(AppTheme.Typography.caption2)
                .foregroundStyle(.secondary)
            Text("Personal best: \(longestStreak) day\(longestStreak == 1 ? "" : "s")")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.Corner.lg, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Corner.lg, style: .continuous)
                    .strokeBorder(tint.opacity(Layout.borderOpacity), lineWidth: Layout.borderLineWidth)
            )
    }
}
