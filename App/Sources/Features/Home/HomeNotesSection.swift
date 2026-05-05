import SwiftUI

struct HomeNotesSection: View {
    @Environment(AppStateStore.self) private var store

    var onCompose: () -> Void
    var onEdit: (Note) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            header

            if notes.isEmpty {
                emptyState
            } else {
                cardsRow
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Notes")
                .font(AppTheme.Typography.headline)
            if !notes.isEmpty {
                Text("\(notes.count)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .glassEffect(.regular, in: .capsule)
            }
            Spacer()
            Button {
                Haptics.selection()
                onCompose()
            } label: {
                Label("New", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("New note")
        }
        .padding(.horizontal, AppTheme.Spacing.xs)
    }

    private var notes: [Note] {
        store.activeNotes.sorted { $0.createdAt > $1.createdAt }
    }

    private var cardsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: AppTheme.Spacing.md) {
                HStack(spacing: AppTheme.Spacing.md) {
                    ForEach(notes) { note in
                        NoteCard(note: note)
                            .onTapGesture {
                                Haptics.selection()
                                onEdit(note)
                            }
                            .contextMenu {
                                Button {
                                    Haptics.selection()
                                    onEdit(note)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    store.deleteNote(note.id)
                                    Haptics.warning()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.xs)
                .padding(.vertical, 2)
            }
            .animation(AppTheme.Animation.spring, value: notes.count)
        }
        .scrollClipDisabled()
    }

    private var emptyState: some View {
        Button {
            Haptics.selection()
            onCompose()
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.yellow)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Write your first note")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(.primary)
                    Text("Capture a thought, reflection, or reminder.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                .regular.tint(.yellow.opacity(0.08)).interactive(),
                in: .rect(cornerRadius: AppTheme.Corner.lg)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NoteCard

private struct NoteCard: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                Image(systemName: kindIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(kindTint)
                Text(titleText)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }

            if !bodyText.isEmpty {
                Text(bodyText)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(relativeDate)
                    .font(AppTheme.Typography.caption2)
            }
            .foregroundStyle(.tertiary)
            .monospacedDigit()
        }
        .padding(AppTheme.Spacing.md)
        .frame(width: 200, height: 150, alignment: .topLeading)
        .glassEffect(
            .regular.tint(kindTint.opacity(0.08)).interactive(),
            in: .rect(cornerRadius: AppTheme.Corner.lg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Corner.lg, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
        )
    }

    private var titleText: String {
        let firstLine = note.text
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            ?? note.text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private var bodyText: String {
        let lines = note.text.components(separatedBy: .newlines)
        guard let firstIdx = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return ""
        }
        let remainder = lines[(firstIdx + 1)...]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return remainder
    }

    private var kindIcon: String {
        switch note.kind {
        case .free: return "note.text"
        case .reflection: return "quote.bubble"
        case .systemEvent: return "gearshape"
        }
    }

    private var kindTint: Color {
        switch note.kind {
        case .free: return .yellow
        case .reflection: return .indigo
        case .systemEvent: return .gray
        }
    }

    private var relativeDate: String {
        let interval = Date().timeIntervalSince(note.createdAt)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86_400 { return "\(Int(interval / 3600))h" }
        if interval < 604_800 { return "\(Int(interval / 86_400))d" }
        return note.createdAt.formatted(date: .abbreviated, time: .omitted)
    }
}
