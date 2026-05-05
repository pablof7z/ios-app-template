import SwiftUI

// MARK: - ItemRow

struct ItemRow: View {
    @Environment(AppStateStore.self) private var store
    let item: Item
    @State private var showNoteInput = false
    @State private var noteText = ""

    private var noteCount: Int {
        store.activeNotes.filter { $0.target == .item(id: item.id) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppTheme.Spacing.md) {
                Button {
                    Haptics.selection()
                    withAnimation(AppTheme.Animation.spring) {
                        store.setItemStatus(item.id, status: item.status == .pending ? .done : .pending)
                    }
                } label: {
                    Image(systemName: item.status == .done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.status == .done ? .green : .secondary)
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .strikethrough(item.status == .done)
                        .foregroundStyle(item.status == .done ? .secondary : .primary)
                        .animation(AppTheme.Animation.spring, value: item.status)

                    if let name = item.requestedByDisplayName {
                        Label(name, systemImage: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: AppTheme.Spacing.xs) {
                    if noteCount > 0 {
                        StatBadge.count(noteCount, color: .purple)
                    }
                    if item.source == .agent {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .opacity(item.status == .done ? 0.55 : 1.0)
            .animation(AppTheme.Animation.spring, value: item.status)
            .padding(.vertical, AppTheme.Spacing.xs)

            if showNoteInput {
                HStack(spacing: AppTheme.Spacing.sm) {
                    TextField("Add a note…", text: $noteText)
                        .font(AppTheme.Typography.caption)
                        .submitLabel(.done)
                        .onSubmit { commitNote() }

                    Button { commitNote() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                    .disabled(noteText.isEmpty)
                }
                .padding(.vertical, AppTheme.Spacing.xs)
                .padding(.horizontal, AppTheme.Spacing.md)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { store.deleteItem(item.id) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                store.setItemStatus(item.id, status: item.status == .done ? .pending : .done)
                Haptics.selection()
            } label: {
                Label(
                    item.status == .done ? "Reopen" : "Done",
                    systemImage: item.status == .done ? "arrow.uturn.left" : "checkmark"
                )
            }
            .tint(.green)
        }
        .contextMenu {
            Button("Add Note", systemImage: "note.text.badge.plus") {
                withAnimation(AppTheme.Animation.spring) { showNoteInput = true }
            }
            Button("Mark \(item.status == .done ? "Pending" : "Done")", systemImage: item.status == .done ? "arrow.uturn.left" : "checkmark.circle") {
                store.setItemStatus(item.id, status: item.status == .done ? .pending : .done)
                Haptics.selection()
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                store.deleteItem(item.id)
            }
        }
    }

    private func commitNote() {
        let text = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            withAnimation(AppTheme.Animation.spring) { showNoteInput = false }
            return
        }
        store.addNote(text: text, target: .item(id: item.id))
        Haptics.success()
        noteText = ""
        withAnimation(AppTheme.Animation.spring) { showNoteInput = false }
    }
}

// MARK: - ThinkingDots

struct ThinkingDots: View {
    @State private var active = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.primary)
                    .frame(width: 5, height: 5)
                    .opacity(active == i ? 1 : 0.25)
                    .scaleEffect(active == i ? 1.2 : 1.0)
            }
        }
        .task {
            while !Task.isCancelled {
                for i in 0..<3 {
                    withAnimation(AppTheme.Animation.springFast) { active = i }
                    try? await Task.sleep(for: .milliseconds(380))
                    if Task.isCancelled { return }
                }
            }
        }
    }
}

// MARK: - Phase helpers

extension AgentSession.Phase {
    var isActive: Bool {
        if case .idle = self { return false }
        return true
    }

    var bannerTint: Color {
        switch self {
        case .running: .blue
        case .completed: .green
        case .failed: .orange
        case .idle: .clear
        }
    }
}
