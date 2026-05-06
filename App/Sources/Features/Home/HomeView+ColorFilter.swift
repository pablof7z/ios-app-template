import SwiftUI

// MARK: - Color Filter UI

extension HomeView {

    // MARK: - Toolbar Button

    /// A color-circle button that opens a Menu for picking a `ColorFilter`.
    /// The icon fills with the selected color when a specific label is active,
    /// making it easy to see at a glance that filtering is on.
    var colorFilterButton: some View {
        Menu {
            colorFilterPicker
        } label: {
            colorFilterIcon
                .accessibilityLabel(colorFilterAccessibilityLabel)
        }
        .animation(AppTheme.Animation.spring, value: currentColorFilter.rawValue)
    }

    // MARK: - Icon

    @ViewBuilder
    private var colorFilterIcon: some View {
        let isFiltering = currentColorFilter != .all
        if isFiltering, let color = currentColorFilter.itemColor {
            // Show the selected color as a filled tinted circle
            Image(systemName: "circle.fill")
                .foregroundStyle(color.swiftUIColor)
                .font(AppTheme.Typography.body)
        } else if currentColorFilter == .uncolored {
            Image(systemName: "circle.slash")
                .foregroundStyle(.secondary)
                .font(AppTheme.Typography.body)
        } else {
            // No filter active — neutral palette icon
            Image(systemName: "circle.hexagonpath")
                .foregroundStyle(.secondary)
                .font(AppTheme.Typography.body)
        }
    }

    // MARK: - Picker

    @ViewBuilder
    private var colorFilterPicker: some View {
        Picker("Color Label", selection: $colorFilterRaw) {
            // "All Colors" option
            Label(ColorFilter.all.label, systemImage: "circle.hexagonpath")
                .tag(ColorFilter.all.rawValue)

            Divider()

            // Individual colors
            ForEach(colorFilterColorCases) { filter in
                Label {
                    Text(filter.label)
                } icon: {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(filter.itemColor?.swiftUIColor ?? .clear)
                }
                .tag(filter.rawValue)
            }

            Divider()

            // Items with no color label
            Label(ColorFilter.uncolored.label, systemImage: "circle.slash")
                .tag(ColorFilter.uncolored.rawValue)
        }
        .pickerStyle(.inline)
    }

    /// Color-specific cases only (excludes `.all` and `.uncolored`).
    private var colorFilterColorCases: [ColorFilter] {
        [.red, .orange, .yellow, .green, .blue, .purple]
    }

    // MARK: - Accessibility

    private var colorFilterAccessibilityLabel: String {
        switch currentColorFilter {
        case .all:       return "Filter by color label — currently showing all"
        case .uncolored: return "Filter by color label — showing unlabeled items"
        default:         return "Filter by color label — showing \(currentColorFilter.label) items"
        }
    }
}
