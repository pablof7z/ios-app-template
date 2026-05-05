import SwiftUI

struct ItemEditSheet: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let item: Item

    @State private var title: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                editor
            }
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .buttonStyle(.glassProminent)
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(180), .medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            title = item.title
            isFocused = true
        }
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            titleField
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.md)
    }

    private var titleField: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.green)
            TextField("What needs doing?", text: $title)
                .font(AppTheme.Typography.body)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { save() }
        }
        .padding(AppTheme.Spacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
    }

    // MARK: - Logic

    private var canSave: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != item.title
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = item
        updated.title = trimmed
        store.updateItem(updated)
        Haptics.success()
        dismiss()
    }

    // MARK: - Background

    private var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.green.opacity(0.05),
                Color.teal.opacity(0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
