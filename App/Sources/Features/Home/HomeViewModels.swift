import Foundation

// MARK: - Sort Order

enum ItemSort: String, CaseIterable, Identifiable {
    case dateAddedDesc = "dateAddedDesc"
    case dateAddedAsc  = "dateAddedAsc"
    case titleAZ       = "titleAZ"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dateAddedDesc: return "Newest First"
        case .dateAddedAsc:  return "Oldest First"
        case .titleAZ:       return "Title A–Z"
        }
    }

    var systemImage: String {
        switch self {
        case .dateAddedDesc: return "arrow.down.circle"
        case .dateAddedAsc:  return "arrow.up.circle"
        case .titleAZ:       return "textformat.abc"
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

// MARK: - AppStorage keys

enum HomeStorageKey {
    static let itemSort     = "home.itemSort"
    static let sourceFilter = "home.sourceFilter"
}

// MARK: - Snooze durations

enum HomeSnooze {
    static let oneHour: TimeInterval    = 3_600
    static let threeHours: TimeInterval = 10_800
    static let tomorrowHour: Int        = 9
}
