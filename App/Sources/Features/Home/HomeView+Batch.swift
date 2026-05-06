import SwiftUI

// MARK: - Batch actions

extension HomeView {

    /// Bottom toolbar shown while in edit mode; provides Complete and Delete actions
    /// for the current selection.
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

                Text(selectionLabel)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)

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
