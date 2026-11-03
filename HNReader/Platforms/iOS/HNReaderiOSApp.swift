import SwiftUI

@main
struct HNReaderiOSApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(appState)
                .tint(.orange)
        }
    }
}
