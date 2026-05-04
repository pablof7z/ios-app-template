import Foundation

/// Persists AppState as a JSON blob in the shared App Group UserDefaults.
/// The App Group allows widgets and extensions to read the same state.
///
/// SETUP: Replace the suite name with your actual App Group identifier.
/// It must match APP_GROUP_IDENTIFIER in Project.swift and your entitlements.
enum Persistence {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.com.yourcompany.apptemplate") ?? .standard
    }

    private static let stateKey = "apptemplate.state.v1"

    static func save(_ state: AppState) {
        guard let data = try? encoder.encode(state) else { return }
        defaults.set(data, forKey: stateKey)
    }

    static func load() throws -> AppState {
        guard let data = defaults.data(forKey: stateKey) else { return AppState() }
        return try decoder.decode(AppState.self, from: data)
    }
}
