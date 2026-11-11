import AppIntents
import SwiftUI

@main
struct HNReaderiOSApp: App {
    @State private var appState: AppState

    init() {
        let appState = AppState()
        _appState = State(initialValue: appState)
        AppDependencyManager.shared.add(dependency: appState)
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(appState)
        }
    }
}

struct OpenHackerNewsLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Open in HNReader"
    static let description = IntentDescription("Open a Hacker News story or comment link in HNReader.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(title: "Hacker News URL", inputConnectionBehavior: .connectToPreviousIntentResult)
    var url: URL

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$url) in HNReader")
    }

    @Dependency private var appState: AppState

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = Item.discussionID(from: url) else {
            throw InvalidHackerNewsLink()
        }

        appState.incomingStoryLink = AppState.StoryLink(itemID: id)
        return .result()
    }

    private struct InvalidHackerNewsLink: LocalizedError {
        var errorDescription: String? {
            String(localized: "Use a Hacker News story or comment link.")
        }
    }
}
