import SwiftUI

/// A small circular progress ring showing today's completion ratio.
///
/// The fill fraction is `completedToday / (completedToday + activeCount)`.
/// When the denominator is 0 the ring renders at 0 % fill (nothing done, nothing active).
/// Animates the arc whenever `completedToday` or `activeCount` changes.
struct TodayProgressRing: View {

    // MARK: - Inputs

    /// Items completed so far today (status == .done && updatedAt is today).
    let completedToday: Int
    /// Items still pending (active).
    let activeCount: Int

    // MARK: - Layout constants

    private enum Layout {
        /// Outer diameter of the ring circle.
        static let diameter: CGFloat = 22
        /// Stroke width of the progress track and fill arc.
        static let lineWidth: CGFloat = 2.5
        /// Opacity of the track (unfilled portion).
        static let trackOpacity: Double = 0.18
    }

    // MARK: - Derived

    private var fraction: Double {
        let total = completedToday + activeCount
        guard total > 0 else { return 0 }
        return min(Double(completedToday) / Double(total), 1.0)
    }

    private var isComplete: Bool { activeCount == 0 && completedToday > 0 }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.accentColor.opacity(Layout.trackOpacity), lineWidth: Layout.lineWidth)

            // Fill arc
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    isComplete ? Color.green : Color.accentColor,
                    style: StrokeStyle(lineWidth: Layout.lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(AppTheme.Animation.spring, value: fraction)

            // Checkmark when all done
            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: Layout.diameter, height: Layout.diameter)
        .animation(AppTheme.Animation.spring, value: isComplete)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHidden(completedToday == 0 && activeCount == 0)
    }

    private var accessibilityLabel: String {
        let total = completedToday + activeCount
        if total == 0 { return "" }
        return "\(completedToday) of \(total) done today"
    }
}
