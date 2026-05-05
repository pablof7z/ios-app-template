import SwiftUI

@main
struct AppTemplateApp: App {
    @State private var store = AppStateStore()
    @State private var userIdentity = UserIdentityStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(userIdentity)
                .task { userIdentity.start() }
        }
    }
}
