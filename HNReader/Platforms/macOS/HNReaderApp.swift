import SwiftUI

@main
struct HNReaderApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .frame(minWidth: 864, minHeight: 600)
                .environment(appState)
        }
        .defaultSize(width: 1600, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .help) {
                Link("Hacker News", destination: URL(string: "https://news.ycombinator.com")!)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
