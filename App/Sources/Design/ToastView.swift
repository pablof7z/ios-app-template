import SwiftUI

// MARK: - Toast model

struct Toast: Identifiable, Equatable {
    enum Style {
        case info, success, warning, error

        var icon: String {
            switch self {
            case .info: "info.circle.fill"
            case .success: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .error: "xmark.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .info: .blue
            case .success: .green
            case .warning: .orange
            case .error: .red
            }
        }
    }

    let id = UUID()
    var message: String
    var style: Style = .info
    var duration: TimeInterval = 2.5
}

// MARK: - ToastModifier

private struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?
    @State private var visible = false
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let t = toast, visible {
                    toastRow(t)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 32)
                        .zIndex(999)
                }
            }
            .onChange(of: toast) { _, new in
                dismissTask?.cancel()
                if let new {
                    withAnimation(AppTheme.Animation.spring) { visible = true }
                    dismissTask = Task {
                        try? await Task.sleep(for: .seconds(new.duration))
                        guard !Task.isCancelled else { return }
                        withAnimation(AppTheme.Animation.easeOut) { visible = false }
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        toast = nil
                    }
                } else {
                    withAnimation(AppTheme.Animation.easeOut) { visible = false }
                }
            }
    }

    @ViewBuilder
    private func toastRow(_ t: Toast) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: t.style.icon)
                .foregroundStyle(t.style.tint)
                .font(.body.weight(.semibold))
            Text(t.message)
                .font(AppTheme.Typography.caption)
                .lineLimit(2)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
        .glassSurface(cornerRadius: 100, tint: t.style.tint)
        .appShadow(AppTheme.Shadow.card)
    }
}

// MARK: - View extension

extension View {
    func toast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}
