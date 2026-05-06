import Foundation

// MARK: - Item Template

/// A predefined item blueprint the user can load into the compose sheet
/// to fast-fill title, details, priority, color, and recurrence.
///
/// Templates ship with the app as static presets. They never mutate persisted
/// state — they only seed `@State` fields inside `ItemComposeSheet`.
struct ItemTemplate: Identifiable, Hashable {
    let id: UUID
    let title: String
    let details: String
    let isPriority: Bool
    let colorLabel: ItemColor?
    let recurrence: Recurrence

    /// SF Symbol shown alongside the template name in the picker.
    let systemImage: String

    /// Short tagline shown below the template name in the picker row.
    let subtitle: String

    private init(
        title: String,
        details: String = "",
        isPriority: Bool = false,
        colorLabel: ItemColor? = nil,
        recurrence: Recurrence = .none,
        systemImage: String,
        subtitle: String
    ) {
        self.id = UUID()
        self.title = title
        self.details = details
        self.isPriority = isPriority
        self.colorLabel = colorLabel
        self.recurrence = recurrence
        self.systemImage = systemImage
        self.subtitle = subtitle
    }
}

// MARK: - Built-in presets

extension ItemTemplate {
    /// All predefined templates in display order.
    static let all: [ItemTemplate] = [
        morningCheckin,
        eveningReflection,
        weeklyReview,
        meetingNotes,
        workout,
        shoppingRun,
    ]

    /// Daily morning intentions check-in.
    static let morningCheckin = ItemTemplate(
        title: "Morning check-in",
        details: "Set intentions for today. What's the one thing that would make today a success?",
        isPriority: true,
        colorLabel: .yellow,
        recurrence: .daily,
        systemImage: "sunrise.fill",
        subtitle: "Daily · Priority · Yellow"
    )

    /// Evening wind-down reflection.
    static let eveningReflection = ItemTemplate(
        title: "Evening reflection",
        details: "What went well today? What could be improved? What am I grateful for?",
        colorLabel: .blue,
        recurrence: .daily,
        systemImage: "moon.stars.fill",
        subtitle: "Daily · Blue"
    )

    /// Weekly high-level review.
    static let weeklyReview = ItemTemplate(
        title: "Weekly review",
        details: "Review the past week: wins, misses, open loops. Plan the top three goals for next week.",
        isPriority: true,
        colorLabel: .purple,
        recurrence: .weekly,
        systemImage: "calendar.badge.checkmark",
        subtitle: "Weekly · Priority · Purple"
    )

    /// Ad-hoc meeting notes stub.
    static let meetingNotes = ItemTemplate(
        title: "Meeting notes",
        details: "Attendees:\nAgenda:\nKey decisions:\nAction items:",
        colorLabel: .green,
        systemImage: "person.2.fill",
        subtitle: "Green"
    )

    /// Recurring workout reminder.
    static let workout = ItemTemplate(
        title: "Workout",
        details: "",
        colorLabel: .orange,
        recurrence: .daily,
        systemImage: "figure.run",
        subtitle: "Daily · Orange"
    )

    /// Quick shopping or errand run.
    static let shoppingRun = ItemTemplate(
        title: "Shopping run",
        details: "",
        colorLabel: .red,
        systemImage: "cart.fill",
        subtitle: "Red"
    )
}
