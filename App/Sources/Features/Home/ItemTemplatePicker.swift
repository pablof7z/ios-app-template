import SwiftUI

// MARK: - Template Picker Sheet

/// A bottom sheet listing all built-in item templates.
/// Tapping a row calls `onSelect` with the chosen template and dismisses.
///
/// Presented from `ItemComposeSheet` when the user taps the Templates toolbar button.
struct ItemTemplatePicker: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (ItemTemplate) -> Void

    var body: some View {
        NavigationStack {
            List(ItemTemplate.all) { template in
                templateRow(template)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(.secondary.opacity(0.3))
            }
            .listStyle(.plain)
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Template Row

    @ViewBuilder
    private func templateRow(_ template: ItemTemplate) -> some View {
        Button {
            Haptics.selection()
            onSelect(template)
            dismiss()
        } label: {
            templateRowLabel(template)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func templateRowLabel(_ template: ItemTemplate) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            templateIcon(template)
            templateText(template)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func templateIcon(_ template: ItemTemplate) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.Corner.sm)
                .fill(iconBackground(for: template))
                .frame(width: TemplatePickerLayout.iconSize, height: TemplatePickerLayout.iconSize)
            Image(systemName: template.systemImage)
                .font(.system(size: TemplatePickerLayout.iconSymbolSize, weight: .medium))
                .foregroundStyle(iconForeground(for: template))
        }
    }

    @ViewBuilder
    private func templateText(_ template: ItemTemplate) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(template.title)
                .font(AppTheme.Typography.body)
                .foregroundStyle(.primary)
            Text(template.subtitle)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func iconBackground(for template: ItemTemplate) -> Color {
        (template.colorLabel?.swiftUIColor ?? Color.accentColor).opacity(0.15)
    }

    private func iconForeground(for template: ItemTemplate) -> Color {
        template.colorLabel?.swiftUIColor ?? Color.accentColor
    }
}

// MARK: - Layout constants

private enum TemplatePickerLayout {
    /// Side length of the rounded-square icon container.
    static let iconSize: CGFloat = 40
    /// Point size of the SF Symbol inside the icon container.
    static let iconSymbolSize: CGFloat = 18
}
