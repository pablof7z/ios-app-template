import SwiftUI

struct ItemComposeSheet: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                editor
            }
            .navigationTitle("New item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .buttonStyle(.glassProminent)
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(220), .medium])
        .presentationDragIndicator(.visible)
        .onAppear { isFocused = true }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
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

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.md)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addItem(title: trimmed, source: .manual)
        Haptics.success()
        dismiss()
    }

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
