import Foundation

// MARK: - Sort Order

enum ItemSort: String, CaseIterable, Identifiable {
    case dateAddedDesc = "dateAddedDesc"
    case dateAddedAsc  = "dateAddedAsc"
    case titleAZ       = "titleAZ"
    case dueDateAsc    = "dueDateAsc"
    case smart         = "smart"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dateAddedDesc: return "Newest First"
        case .dateAddedAsc:  return "Oldest First"
        case .titleAZ:       return "Title A–Z"
        case .dueDateAsc:    return "Due Date"
        case .smart:         return "Smart"
        }
    }

    var systemImage: String {
        switch self {
        case .dateAddedDesc: return "arrow.down.circle"
        case .dateAddedAsc:  return "arrow.up.circle"
        case .titleAZ:       return "textformat.abc"
        case .dueDateAsc:    return "calendar"
        case .smart:         return "sparkles"
        }
    }
}

// MARK: - Smart Sort

/// Weights used by the "Smart" sort option to produce a single urgency score.
///
/// Higher weight → item ranks earlier (higher priority). All weights are
/// additive and non-negative so the formula is easy to reason about:
///
///   score = priorityBoost + overdueBoost + dueSoonBoost + recurrenceBoost - ageDecay
///
/// The final `.smart` sort in `HomeView.sortedActiveItems` sorts descending by score.
enum SmartSortWeights {
    /// Flat bonus for starred (priority) items.
    static let priorityBoost: Double    = 100
    /// Flat bonus when the item's due date is in the past.
    static let overdueBoost: Double     = 80
    /// Flat bonus when the item is due within the next 24 hours.
    static let dueSoonBoost: Double     = 40
    /// Flat bonus for recurring items — they represent ongoing commitments.
    static let recurrenceBoost: Double  = 20
    /// Decay applied per day of age, capped at `maxAgeDays` to avoid burying new items.
    static let ageDecayPerDay: Double   = 1
    /// Maximum number of days of decay applied (prevents ancient items falling to the bottom forever).
    static let maxAgeDays: Double       = 30
    /// Number of seconds in one calendar day — used to convert `timeIntervalSince` to days.
    static let secondsPerDay: Double    = 86_400
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

