import SwiftUI

// MARK: - Item Color Picker Row

/// A horizontal chip strip that lets the user pick a color label (or clear it).
/// Used in both `ItemComposeSheet` and `ItemEditSheet` to keep the UI in sync.
struct ItemColorPickerRow: View {

    @Binding var selection: ItemColor?

    private enum Layout {
        /// Diameter of each color chip circle.
        static let chipSize: CGFloat = 28
        /// Diameter of the checkmark overlay on the selected chip.
        static let checkmarkSize: CGFloat = 14
        /// Diameter of the "clear" (none) chip circle.
        static let clearChipSize: CGFloat = 28
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: ItemLayout.rowIconSize, weight: .regular))
                .foregroundStyle(selection.map { $0.swiftUIColor } ?? Color.secondary)
            Text("Color")
                .font(AppTheme.Typography.body)
                .foregroundStyle(selection != nil ? .primary : .secondary)
            Spacer(minLength: 0)
            colorChips
        }
        .padding(AppTheme.Spacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
        .accessibilityLabel("Color label")
        .accessibilityValue(selection?.label ?? "None")
    }

    // MARK: - Chip strip

    private var colorChips: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            noneChip
            ForEach(ItemColor.allCases, id: \.self) { color in
                colorChip(color)
            }
        }
    }

    private var noneChip: some View {
        Button {
            Haptics.selection()
            withAnimation(AppTheme.Animation.springFast) { selection = nil }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1.5)
                    .frame(width: Layout.clearChipSize, height: Layout.clearChipSize)
                if selection == nil {
                    Image(systemName: "checkmark")
                        .font(.system(size: Layout.checkmarkSize, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("No color")
        .accessibilityAddTraits(selection == nil ? .isSelected : [])
    }

    private func colorChip(_ color: ItemColor) -> some View {
        let isSelected = selection == color
        return Button {
            Haptics.selection()
            withAnimation(AppTheme.Animation.springFast) {
                selection = isSelected ? nil : color
            }
        } label: {
            ZStack {
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: Layout.chipSize, height: Layout.chipSize)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: Layout.checkmarkSize, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
