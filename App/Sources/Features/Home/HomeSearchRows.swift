import SwiftUI

// Result row views and helpers used by HomeSearchView. Extracted to keep
// HomeSearchView under the 300-line soft limit. These rows take data only
// (no state from the parent) so the split is clean.

struct ItemResultRow: View {
    let item: Item
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: item.status == .done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(item.status == .done ? AnyShapeStyle(Color.green) : AnyShapeStyle(.secondary))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title.isEmpty ? "Untitled" : item.title)
                    .font(AppTheme.Typography.body)
                    .strikethrough(item.status == .done, color: .secondary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                Text(searchRowRelativeDate(item.createdAt))
                    .font(AppTheme.Typography.caption2).foregroundStyle(.tertiary).monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

struct NoteResultRow: View {
    let note: Note
    let query: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snippet)
                .font(AppTheme.Typography.body)
                .lineLimit(3).multilineTextAlignment(.leading)
            Text(searchRowRelativeDate(note.createdAt))
                .font(AppTheme.Typography.caption2).foregroundStyle(.tertiary).monospacedDigit()
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var snippet: String {
        let trimmed = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Untitled" }
        guard !query.isEmpty,
              let range = trimmed.range(of: query, options: .caseInsensitive)
        else { return trimmed }
        let lower = trimmed.distance(from: trimmed.startIndex, to: range.lowerBound)
        guard lower > 32 else { return trimmed }
        let start = trimmed.index(range.lowerBound, offsetBy: -32)
        return "\u{2026}" + String(trimmed[start...])
    }
}

struct MemoryResultRow: View {
    let memory: AgentMemory
    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: "brain").font(.caption).foregroundStyle(.purple).padding(.top, 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.content)
                    .font(AppTheme.Typography.callout)
                    .lineLimit(3).multilineTextAlignment(.leading)
                Text(searchRowRelativeDate(memory.createdAt))
                    .font(AppTheme.Typography.caption2).foregroundStyle(.tertiary).monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FriendResultRow: View {
    let friend: Friend
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            FriendAvatar(friend: friend, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName).font(AppTheme.Typography.body)
                Text(friend.shortIdentifier)
                    .font(AppTheme.Typography.mono).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

func searchRowRelativeDate(_ date: Date) -> String {
    let interval = Date().timeIntervalSince(date)
    if interval < 60 { return "just now" }
    if interval < 3600 { return "\(Int(interval / 60))m" }
    if interval < 86_400 { return "\(Int(interval / 3600))h" }
    if interval < 604_800 { return "\(Int(interval / 86_400))d" }
    return date.formatted(date: .abbreviated, time: .omitted)
}
