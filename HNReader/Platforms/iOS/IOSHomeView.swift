import SwiftUI
import UIKit

struct IOSHomeView: View {
    enum Tab: Hashable {
        case stories
        case search
        case saved
        case profile
    }

    @Environment(AppState.self) private var appState

    @State private var selectedTab: Tab
    @State private var selectedFeed: AppState.SidebarSelection = .top
    @State private var storyLink: AppState.StoryLink?
    private let initialRows: [StoryRow]
    private let repository: FeedRepository
    private let loadsAutomatically: Bool
    private let previewComments: [Item]?
    private let previewThreads: [Int: [Item]]?
    private let profileAccount: HNAuthenticatedAccount?
    private let profileUser: User?

    init(
        initialRows: [StoryRow] = [],
        repository: FeedRepository = .shared,
        loadsAutomatically: Bool = true,
        previewComments: [Item]? = nil,
        previewThreads: [Int: [Item]]? = nil,
        initialTab: Tab = .stories,
        profileAccount: HNAuthenticatedAccount? = nil,
        profileUser: User? = nil
    ) {
        self.initialRows = initialRows
        self.repository = repository
        self.loadsAutomatically = loadsAutomatically
        self.previewComments = previewComments
        self.previewThreads = previewThreads
        self.profileAccount = profileAccount
        self.profileUser = profileUser
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            IOSStoryList(
                selection: $selectedFeed,
                showsSavedStories: false,
                initialRows: initialRows,
                repository: repository,
                loadsAutomatically: loadsAutomatically,
                previewComments: previewComments,
                previewThreads: previewThreads,
                storyLink: $storyLink
            )
            .tabItem {
                tabLabel("Stories", systemImage: "newspaper.fill")
            }
            .tag(Tab.stories)

            NavigationStack {
                StorySearchView()
            }
            .tabItem {
                tabLabel("Search", systemImage: "magnifyingglass")
            }
            .tag(Tab.search)

            IOSStoryList(
                selection: .constant(.saved),
                showsSavedStories: true,
                repository: repository,
                loadsAutomatically: loadsAutomatically,
                previewComments: previewComments,
                previewThreads: previewThreads
            )
            .tabItem {
                tabLabel("Saved", systemImage: "bookmark.fill")
            }
            .tag(Tab.saved)

            NavigationStack {
                HNAccountView(
                    account: profileAccount,
                    previewUser: profileUser,
                    loadsAutomatically: loadsAutomatically
                )
            }
            .tabItem {
                tabLabel("Profile", systemImage: "person.fill")
            }
            .tag(Tab.profile)
        }
        .onChange(of: appState.incomingStoryLink, initial: true) { _, link in
            guard let link else { return }
            selectedTab = .stories
            storyLink = link
            appState.incomingStoryLink = nil
        }
    }

    private func tabLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let icon: Image
        if let symbol = UIImage(systemName: systemImage, withConfiguration: configuration) {
            // Render the symbol at its configured size before the tab bar applies its tint.
            let image = UIGraphicsImageRenderer(size: symbol.size).image { _ in
                symbol.draw(at: .zero)
            }
            icon = Image(uiImage: image.withRenderingMode(.alwaysTemplate))
        } else {
            icon = Image(systemName: systemImage)
        }

        return Label {
            Text(title)
        } icon: {
            icon
        }
    }
}

#if DEBUG
    /// Full iOS home experience with local story data and working navigation.
    @MainActor
    private struct IOSHomeMockCanvas: View {
        @State private var appState = PreviewData.appState()

        var body: some View {
            IOSHomeView(
                initialRows: PreviewData.rows,
                loadsAutomatically: false,
                previewComments: PreviewData.rootComments,
                previewThreads: PreviewData.threads
            )
            .environment(appState)
        }
    }

    #Preview("iOS · Home · Interactive Mock") {
        IOSHomeMockCanvas()
    }

    struct IOSStoryListCanvas: View {
        var selectedItem: Item? = nil
        @State private var appState = PreviewData.appState()
        @State private var selectedFeed: AppState.SidebarSelection = .top

        var body: some View {
            IOSStoryList(
                selection: $selectedFeed,
                showsSavedStories: false,
                initialRows: PreviewData.rows,
                initialSelectedItem: selectedItem,
                loadsAutomatically: false,
                previewComments: PreviewData.rootComments,
                previewThreads: PreviewData.threads
            )
            .environment(appState)
        }
    }

    #Preview("iOS · Two Columns · No Selection", traits: .fixedLayout(width: 1000, height: 700)) {
        IOSStoryListCanvas()
            .environment(\.horizontalSizeClass, .regular)
    }

    #Preview("iOS · Two Columns · Discussion", traits: .fixedLayout(width: 1000, height: 700)) {
        IOSStoryListCanvas(selectedItem: PreviewData.stories.first)
            .environment(\.horizontalSizeClass, .regular)
    }

    #Preview("iOS · Two Columns · Saved Empty", traits: .fixedLayout(width: 1000, height: 700)) {
        IOSStoryList(
            selection: .constant(.saved),
            showsSavedStories: true,
            loadsAutomatically: false,
            previewComments: nil,
            previewThreads: nil
        )
        .environment(PreviewData.appState(includeSavedStories: false))
        .environment(\.horizontalSizeClass, .regular)
    }

    /// The real Saved screen populated with local stories, comments, and replies.
    struct IOSSavedItemsCanvas: View {
        @State private var appState = PreviewData.appState(
            savedItems: zip(PreviewData.stories, PreviewData.comments).flatMap { [$0.0, $0.1] }
        )

        var body: some View {
            IOSStoryList(
                selection: .constant(.saved),
                showsSavedStories: true,
                initialRows: PreviewData.rows,
                loadsAutomatically: false,
                previewComments: PreviewData.rootComments,
                previewThreads: PreviewData.threads
            )
            .environment(appState)
        }
    }

    #Preview("iOS · Saved Stories & Comments · Light (Mock)") {
        IOSSavedItemsCanvas()
            .preferredColorScheme(.light)
    }

    #Preview("iOS · Saved Stories & Comments · Dark (Mock)") {
        IOSSavedItemsCanvas()
            .preferredColorScheme(.dark)
    }

    /// An interactive Canvas backed by the same live API and detail view as the app.
    private struct IOSLiveArticleCanvas: View {
        private static let storyID = 8863

        @State private var appState = PreviewData.appState(includeSavedStories: false)
        @State private var item: Item?
        @State private var errorMessage: String?
        @State private var isLoading = false
        @State private var requestID = UUID()

        var body: some View {
            NavigationStack {
                Group {
                    if let item {
                        StoryDetail(item: item)
                            .navigationBarTitleDisplayMode(.inline)
                    } else if let errorMessage {
                        ContentUnavailableView {
                            Label("Couldn’t load the article", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(errorMessage)
                        } actions: {
                            Button("Try Again") {
                                requestID = UUID()
                            }
                        }
                    } else {
                        ProgressView("Loading a real HN article…")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .environment(appState)
            .task(id: requestID) {
                await loadArticle()
            }
        }

        @MainActor
        private func loadArticle() async {
            guard !isLoading else { return }

            isLoading = true
            item = nil
            errorMessage = nil

            defer {
                isLoading = false
            }

            do {
                guard
                    let loaded = try await NewsService.shared.item(
                        id: Self.storyID,
                        forceRefresh: true
                    )
                else {
                    throw URLError(.resourceUnavailable)
                }

                item = loaded
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    #Preview("iOS · Live HN Article") {
        IOSLiveArticleCanvas()
    }
#endif
