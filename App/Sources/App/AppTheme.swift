import SwiftUI

enum AppTheme {
    enum Color {
        static let accent = SwiftUI.Color.accentColor
        static let background = SwiftUI.Color(uiColor: .systemBackground)
        static let secondaryBackground = SwiftUI.Color(uiColor: .secondarySystemBackground)
        static let label = SwiftUI.Color(uiColor: .label)
        static let secondaryLabel = SwiftUI.Color(uiColor: .secondaryLabel)
        static let separator = SwiftUI.Color(uiColor: .separator)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Corner {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
}
