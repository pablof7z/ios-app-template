import SwiftUI

@main
struct AppTemplateApp: App {
    @State private var store = AppStateStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
