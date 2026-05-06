import Foundation

// MARK: - Sort Order

enum ItemSort: String, CaseIterable, Identifiable {
    case dateAddedDesc = "dateAddedDesc"
    case dateAddedAsc  = "dateAddedAsc"
    case titleAZ       = "titleAZ"
    case dueDateAsc    = "dueDateAsc"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dateAddedDesc: return "Newest First"
        case .dateAddedAsc:  return "Oldest First"
        case .titleAZ:       return "Title A–Z"
        case .dueDateAsc:    return "Due Date"
        }
    }

    var systemImage: String {
        switch self {
        case .dateAddedDesc: return "arrow.down.circle"
        case .dateAddedAsc:  return "arrow.up.circle"
        case .titleAZ:       return "textformat.abc"
        case .dueDateAsc:    return "calendar"
        }
    }
}

// MARK: - Source Filter

enum SourceFilter: String, CaseIterable, Identifiable {
    case all    = "all"
    case manual = "manual"
    case agent  = "agent"
    case voice  = "voice"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:    return "All"
        case .manual: return "Manual"
        case .agent:  return "Agent"
        case .voice:  return "Voice"
        }
    }
}

// MARK: - Today Filter

/// Controls whether the list shows all items or only those due / reminding today.
enum TodayFilter: String, CaseIterable, Identifiable {
    case all   = "all"
    case today = "today"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:   return "All"
        case .today: return "Today"
        }
    }

    /// Returns `true` if `item` passes the filter.
    func matches(_ item: Item) -> Bool {
        switch self {
        case .all: return true
        case .today:
            let cal = Calendar.current
            let dueTodayMatch  = item.dueDate.map  { cal.isDateInToday($0) } ?? false
            let remTodayMatch  = item.reminderAt.map { cal.isDateInToday($0) } ?? false
            return dueTodayMatch || remTodayMatch
        }
    }
}

// MARK: - AppStorage keys

enum HomeStorageKey {
    static let itemSort     = "home.itemSort"
    static let sourceFilter = "home.sourceFilter"
    static let todayFilter  = "home.todayFilter"
}

// MARK: - Snooze durations

enum HomeSnooze {
    static let oneHour: TimeInterval    = 3_600
    static let threeHours: TimeInterval = 10_800
    static let tomorrowHour: Int        = 9
}

// MARK: - Item sheet layout constants
// Shared by ItemComposeSheet, ItemEditSheet, and ItemRow to keep the
// checkmark icon and row-icon sizes consistent across all three surfaces.

enum ItemSheetLayout {
    /// Point size of the leading checkmark circle icon in compose/edit title fields.
    /// Matches `ItemRow.Layout.checkmarkSize` so the icon reads the same in list and sheet.
    static let checkmarkSize: CGFloat = 22
    /// Point size of the small leading icon in detail/recurrence rows.
    static let rowIconSize: CGFloat = 16
    /// Default look-ahead applied to `Date()` when a reminder picker first appears.
    static let defaultReminderOffset: TimeInterval = 3_600
}
