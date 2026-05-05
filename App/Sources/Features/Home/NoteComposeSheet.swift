import SwiftUI

struct NoteComposeSheet: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let editing: Note?

    @State private var text: String = ""
    @State private var showDeleteConfirm = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                editor
            }
            .navigationTitle(editing == nil ? "New note" : "Edit note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Save" : "Done") {
                        save()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
                if editing != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete note", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let editing { text = editing.text }
            isFocused = true
        }
        .alert("Delete note?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let editing {
                    store.deleteNote(editing.id)
                    Haptics.success()
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This note will be removed.")
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            TextEditor(text: $text)
                .font(AppTheme.Typography.body)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("What's on your mind?")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, AppTheme.Spacing.md + 5)
                            .padding(.vertical, AppTheme.Spacing.md + 8)
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(timestampLabel)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(characterCount)")
                    .font(AppTheme.Typography.mono)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, AppTheme.Spacing.xs)
        }
        .padding(AppTheme.Spacing.md)
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var characterCount: Int {
        text.count
    }

    private var timestampLabel: String {
        if let editing {
            return editing.createdAt.formatted(date: .abbreviated, time: .shortened)
        }
        return "Now"
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if var existing = editing {
            existing.text = trimmed
            store.updateNote(existing)
            Haptics.light()
        } else {
            store.addNote(text: trimmed)
            Haptics.success()
        }
        dismiss()
    }

    private var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.indigo.opacity(0.05),
                Color.blue.opacity(0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
