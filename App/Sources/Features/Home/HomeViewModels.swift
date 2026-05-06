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

// MARK: - Color Filter

/// Restricts the active-items list to items with a specific color label (or no label).
enum ColorFilter: String, CaseIterable, Identifiable {
    case all       = "all"
    case uncolored = "uncolored"
    case red       = "red"
    case orange    = "orange"
    case yellow    = "yellow"
    case green     = "green"
    case blue      = "blue"
    case purple    = "purple"

    var id: String { rawValue }

    /// Human-readable name used in the Menu.
    var label: String {
        switch self {
        case .all:       return "All Colors"
        case .uncolored: return "No Label"
        case .red:       return ItemColor.red.label
        case .orange:    return ItemColor.orange.label
        case .yellow:    return ItemColor.yellow.label
        case .green:     return ItemColor.green.label
        case .blue:      return ItemColor.blue.label
        case .purple:    return ItemColor.purple.label
        }
    }

    /// The `ItemColor` this filter matches, or `nil` for `.all` and `.uncolored`.
    var itemColor: ItemColor? {
        switch self {
        case .all, .uncolored: return nil
        case .red:    return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green:  return .green
        case .blue:   return .blue
        case .purple: return .purple
        }
    }

    /// Returns `true` if `item` passes this filter.
    func matches(_ item: Item) -> Bool {
        switch self {
        case .all:       return true
        case .uncolored: return item.colorLabel == nil
        default:         return item.colorLabel == itemColor
        }
    }
}

// MARK: - AppStorage keys

enum HomeStorageKey {
    static let itemSort     = "home.itemSort"
    static let sourceFilter = "home.sourceFilter"
    static let todayFilter  = "home.todayFilter"
    static let colorFilter  = "home.colorFilter"
}

// MARK: - Snooze durations

enum HomeSnooze {
    static let oneHour: TimeInterval    = 3_600
    static let threeHours: TimeInterval = 10_800
    static let tomorrowHour: Int        = 9
}

// MARK: - Item layout constants
// Shared by ItemComposeSheet, ItemEditSheet, ItemRow, and CompletedItemRow to keep
// the checkmark icon and row-icon sizes consistent across all item surfaces.

enum ItemLayout {
    /// Point size of the leading checkmark circle icon in list rows and compose/edit sheets.
    static let checkmarkSize: CGFloat = 22
    /// Point size of the small leading icon in detail/recurrence sheet rows.
    static let rowIconSize: CGFloat = 16
    /// Default look-ahead applied to `Date()` when a reminder picker first appears.
    static let defaultReminderOffset: TimeInterval = 3_600
}

