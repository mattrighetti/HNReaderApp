import SwiftUI

struct HomeView: View {
    var initialRows: [StoryRow] = []
    var initialSelection: AppState.SidebarSelection = .top
    var initialUnreadOnly = false
    var repository: FeedRepository = .shared
    var selectedID: Int?
    var loadsAutomatically = true
    var previewComments: [Item]?
    var previewThreads: [Int: [Item]]?

    var body: some View {
        #if os(iOS)
            IOSHomeView(
                initialRows: initialRows, repository: repository,
                loadsAutomatically: loadsAutomatically,
                previewComments: previewComments, previewThreads: previewThreads)
        #else
            MacReaderView(
                initialRows: initialRows, initialSelection: initialSelection,
                initialUnreadOnly: initialUnreadOnly, repository: repository,
                selectedID: selectedID, loadsAutomatically: loadsAutomatically,
                previewComments: previewComments, previewThreads: previewThreads)
        #endif
    }
}

#if DEBUG && os(macOS)
    #Preview("Reader · Light", traits: .fixedLayout(width: 1600, height: 820)) {
        HomeView(
            initialRows: PreviewData.rows,
            selectedID: PreviewData.stories.first?.id,
            loadsAutomatically: false,
            previewComments: PreviewData.rootComments,
            previewThreads: PreviewData.threads
        )
        .environment(PreviewData.appState())
        .preferredColorScheme(.light)
    }

    #Preview("Reader · Dark", traits: .fixedLayout(width: 1600, height: 820)) {
        HomeView(
            initialRows: PreviewData.rows,
            selectedID: PreviewData.stories.first?.id,
            loadsAutomatically: false,
            previewComments: PreviewData.rootComments,
            previewThreads: PreviewData.threads
        )
        .environment(PreviewData.appState())
        .preferredColorScheme(.dark)
    }

    #Preview("Reader · No selection", traits: .fixedLayout(width: 1600, height: 820)) {
        HomeView(
            initialRows: PreviewData.rows,
            loadsAutomatically: false
        )
        .environment(PreviewData.appState())
    }

    #Preview("Sidebar", traits: .fixedLayout(width: 205, height: 600)) {
        Sidebar(selection: .constant(.top))
            .environment(PreviewData.appState())
    }
#endif

#if DEBUG && os(iOS)
    #Preview("Reader · iOS") {
        HomeView(
            initialRows: PreviewData.rows,
            loadsAutomatically: false,
            previewComments: PreviewData.rootComments,
            previewThreads: PreviewData.threads
        )
        .environment(PreviewData.appState())
    }
#endif
