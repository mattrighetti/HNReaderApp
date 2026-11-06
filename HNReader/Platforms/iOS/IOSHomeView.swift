import SwiftUI

struct IOSHomeView: View {
    enum Tab: Hashable {
        case stories
        case saved
        case profile
    }

    @State private var selectedTab: Tab
    @State private var selectedFeed: AppState.SidebarSelection = .top
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
                previewThreads: previewThreads
            )
            .tabItem {
                Label("Stories", systemImage: "newspaper")
            }
            .tag(Tab.stories)

            IOSStoryList(
                selection: .constant(.saved), showsSavedStories: true,
                repository: repository, loadsAutomatically: loadsAutomatically,
                previewComments: previewComments, previewThreads: previewThreads
            )
            .tabItem {
                Label("Saved", systemImage: "bookmark")
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
                Label("Profile", systemImage: "person.crop.circle")
            }
            .tag(Tab.profile)
        }
    }
}

#if DEBUG
    struct IOSStoryListCanvas: View {
        @State private var appState = PreviewData.appState()
        @State private var selectedFeed: AppState.SidebarSelection = .top

        var body: some View {
            IOSStoryList(
                selection: $selectedFeed,
                showsSavedStories: false,
                initialRows: PreviewData.rows,
                loadsAutomatically: false,
                previewComments: PreviewData.rootComments,
                previewThreads: PreviewData.threads
            )
            .environment(appState)
        }
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
                            .navigationTitle("Story")
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
