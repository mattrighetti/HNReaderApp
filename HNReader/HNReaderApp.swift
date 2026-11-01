import SwiftUI

@main
struct HNReaderApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .frame(minWidth: 1440, minHeight: 600)
                .preferredColorScheme(appState.colorScheme)
                .environmentObject(appState)
                .tint(.orange)
        }
        .defaultSize(width: 1600, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .help) {
                Link("Hacker News", destination: URL(string: "https://news.ycombinator.com")!)
            }
        }

        Settings {
            Form {
                Picker("Appearance", selection: $appState.displayMode) {
                    ForEach(AppState.DisplayMode.allCases, id: \.rawValue) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(24)
            .frame(width: 360)
            .preferredColorScheme(appState.colorScheme)
        }
    }
}
