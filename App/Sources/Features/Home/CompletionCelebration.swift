import SwiftUI

// MARK: - CompletionCelebration

/// Full-screen overlay that plays a brief sparkle burst when an item is completed.
///
/// Instantiate once (e.g. as an `@State` on the parent) and call ``trigger()``
/// inside your completion handler.  The overlay is transparent to hit-testing.
@MainActor
final class CompletionCelebrationState: ObservableObject {
    @Published var isVisible = false
    @Published var checkmarkScale: CGFloat = 0.1
    @Published var checkmarkOpacity: Double = 0
    @Published var particleProgress: CGFloat = 0
    @Published var globalOpacity: Double = 0

    private enum Timing {
        static let enterDuration: Double = 0.38
        static let exitDelay: Double     = 0.52   // totalLifetime - exitDuration
        static let exitDuration: Double  = 0.28
        static let totalLifetime: Double = 0.80
    }

    var isBusy = false

    /// Fire one celebration burst.
    func trigger() {
        guard !isBusy else { return }
        isBusy = true
        isVisible = true
        globalOpacity = 1

        withAnimation(AppTheme.Animation.springBouncy) {
            checkmarkScale   = 1.0
            checkmarkOpacity = 1.0
        }
        withAnimation(.easeOut(duration: Timing.enterDuration)) {
            particleProgress = 1.0
        }
        withAnimation(.easeIn(duration: Timing.exitDuration).delay(Timing.exitDelay)) {
            globalOpacity = 0
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Timing.totalLifetime + 0.05))
            isVisible        = false
            checkmarkScale   = 0.1
            checkmarkOpacity = 0
            particleProgress = 0
            isBusy = false
        }
    }
}

// MARK: - CompletionCelebrationView

struct CompletionCelebrationView: View {

    @ObservedObject var state: CompletionCelebrationState

    // MARK: - Constants

    private enum Layout {
        static let particleCount: Int    = 12
        static let checkmarkSize: CGFloat = 56
        static let burstRadius: CGFloat   = 72
        /// Upward offset so burst appears in the upper-middle of the list.
        static let verticalOffset: CGFloat = -80
        /// Point size of each sparkle particle glyph.
        static let sparkleSize: CGFloat = 14
    }

    var body: some View {
        ZStack {
            if state.isVisible {
                particleRing
                checkmark
            }
        }
        .offset(y: Layout.verticalOffset)
        .opacity(state.globalOpacity)
        .allowsHitTesting(false)
    }

    // MARK: - Subviews

    private var checkmark: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: Layout.checkmarkSize, weight: .semibold))
            .foregroundStyle(.green)
            .scaleEffect(state.checkmarkScale)
            .opacity(state.checkmarkOpacity)
    }

    private var particleRing: some View {
        ForEach(0..<Layout.particleCount, id: \.self) { index in
            sparkle(index: index)
        }
    }

    private func sparkle(index: Int) -> some View {
        let total  = Layout.particleCount
        let angle  = Double(index) / Double(total) * 2 * .pi
        let dx     = CGFloat(cos(angle)) * Layout.burstRadius * state.particleProgress
        let dy     = CGFloat(sin(angle)) * Layout.burstRadius * state.particleProgress
        let scale  = CGFloat(1 - state.particleProgress * 0.5)
        let opacity = Double(1 - state.particleProgress * 0.6)

        return Image(systemName: "sparkle")
            .font(.system(size: Layout.sparkleSize, weight: .bold))
            .foregroundStyle(palette[index % palette.count])
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: dx, y: dy)
    }

    private let palette: [Color] = [.green, .teal, .mint, .cyan, .yellow, .orange]
}
