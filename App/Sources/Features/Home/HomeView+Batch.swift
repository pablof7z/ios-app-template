import SwiftUI

// MARK: - Batch actions

extension HomeView {

    /// Bottom toolbar shown while in edit mode; provides Complete, color-label, and Delete
    /// actions for the current selection.
    @ToolbarContentBuilder
    var batchToolbar: some ToolbarContent {
        if isEditing {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    batchComplete()
                } label: {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(AppTheme.Typography.body)
                }
                .disabled(selectedIDs.isEmpty)
                .tint(.green)
                .accessibilityLabel("Complete selected items")

                Spacer()

                batchColorMenu

                Spacer()

                Button(role: .destructive) {
                    batchDelete()
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                        .font(AppTheme.Typography.body)
                }
                .disabled(selectedIDs.isEmpty)
                .tint(.red)
                .accessibilityLabel("Delete selected items")
            }
        }
    }

    // MARK: - Color Menu

    /// A centre-bar Menu that shows the selection count and lets the user bulk-assign
    /// a color label (or clear it) across all selected items in one tap.
    private var batchColorMenu: some View {
        Menu {
            // Color options
            ForEach(ItemColor.allCases, id: \.self) { color in
                Button {
                    batchSetColor(color)
                } label: {
                    Label(color.label, systemImage: "circle.fill")
                }
            }

            Divider()

            // Clear label
            Button {
                batchSetColor(nil)
            } label: {
                Label("No Color", systemImage: "circle.slash")
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "circle.hexagonpath")
                    .font(AppTheme.Typography.body)
                Text(selectionLabel)
                    .font(AppTheme.Typography.caption2)
            }
            .foregroundStyle(selectedIDs.isEmpty ? Color.secondary : Color.primary)
        }
        .disabled(selectedIDs.isEmpty)
        .accessibilityLabel("Set color label — \(selectionLabel)")
    }

    // MARK: - Helpers

    private var selectionLabel: String {
        switch selectedIDs.count {
        case 0:  return "Select items"
        case 1:  return "1 selected"
        default: return "\(selectedIDs.count) selected"
        }
    }

    /// Marks all selected items as done in a single pass, fires one celebration.
    func batchComplete() {
        guard !selectedIDs.isEmpty else { return }
        let ids = selectedIDs
        for id in ids {
            store.setItemStatus(id, status: .done)
        }
        Haptics.success()
        celebration.trigger()
        exitEditMode()
    }

    /// Sets the color label on all selected items in a single pass.
    /// Pass `nil` to clear the label.
    func batchSetColor(_ color: ItemColor?) {
        guard !selectedIDs.isEmpty else { return }
        let ids = selectedIDs
        for id in ids {
            store.setItemColorLabel(id, color: color)
        }
        Haptics.selection()
        exitEditMode()
    }

    /// Soft-deletes all selected items in a single pass.
    func batchDelete() {
        guard !selectedIDs.isEmpty else { return }
        let ids = selectedIDs
        for id in ids {
            store.deleteItem(id)
        }
        Haptics.medium()
        exitEditMode()
    }

    private func exitEditMode() {
        selectedIDs = []
        editMode?.wrappedValue = .inactive
    }
}
