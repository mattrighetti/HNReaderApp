import SwiftUI

/// Restart a visible footer when loading finishes or the page cursor advances.
struct FeedPaginationTrigger: Equatable {
    let revision: UUID
    let isLoading: Bool
    let nextOffset: Int
}

struct ItemList: View {
    let rows: [StoryRow]
    let revision: UUID
    let nextOffset: Int

    @Binding var selectedID: Int?

    let title: String
    let isLoading: Bool
    let isLoadingMore: Bool
    let hasMore: Bool
    let paginationError: String?
    let errorMessage: String?
    let isSaved: Bool

    @Binding var unreadOnly: Bool

    let refresh: () async -> Void
    let loadMore: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Couldn’t load stories", systemImage: "wifi.exclamationmark")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Try Again") {
                        Task {
                            await refresh()
                        }
                    }
                    .clickableCursor()
                }
                .padding()
            }

            if isLoading && rows.isEmpty {
                Spacer()

                ProgressView("Gathering stories…")

                Spacer()
            } else if rows.isEmpty && errorMessage == nil {
                emptyState

                if canLoadMore {
                    emptyPaginationControls
                }
            } else {
                List(selection: $selectedID) {
                    ForEach(rows) { row in
                        ItemCell(
                            item: row.item,
                            rank: row.rank,
                            isSelected: selectedID == row.id
                        )
                        .help(row.item.title ?? "Saved comment")
                        .frame(minHeight: StoryRowLayout.minimumHeight)
                        .tag(row.id)
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                        .listRowSeparator(.hidden)
                    }

                    if canLoadMore {
                        paginationFooter
                    }
                }
                .listStyle(.inset)
                .environment(\.defaultMinListRowHeight, StoryRowLayout.minimumHeight)
                .transaction {
                    $0.animation = nil
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(PlatformColors.controlBackground)
        .navigationTitle(title)
        .toolbar {
            Toggle(isOn: $unreadOnly) {
                Label("Unread only", systemImage: "circle.lefthalf.filled")
            }
            .clickableCursor()
            .toggleStyle(.button)
            .help(
                isSaved
                    ? "Show only saved items you haven’t read"
                    : "Show only stories you haven’t read")

            if !isSaved {
                Button {
                    Task {
                        await refresh()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .clickableCursor()
                .keyboardShortcut("r", modifiers: .command)
                .disabled(isLoading)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: isSaved ? "bookmark" : "newspaper")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(emptyStateContent.title)
                    .font(.headline)

                Text(emptyStateContent.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateContent: (title: String, description: String) {
        if unreadOnly {
            if canLoadMore {
                return (
                    "No unread stories in loaded pages",
                    "Load more stories to look for unread items."
                )
            }

            return isSaved
                ? ("No unread saved items", "Turn off Unread only to see saved items you’ve read.")
                : ("No unread stories", "Turn off Unread only to see stories you’ve read.")
        }

        if isSaved {
            return ("No saved items", "Use the bookmark button to save a story or comment.")
        }

        let description =
            canLoadMore ? "Load more stories to continue." : "Refresh to check for stories."

        return ("No stories to show", description)
    }

    private var canLoadMore: Bool {
        hasMore && !isSaved
    }

    private var emptyPaginationControls: some View {
        VStack(spacing: 8) {
            if let paginationError {
                Text(paginationError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if isLoadingMore {
                ProgressView("Loading next 30 stories…")
                    .controlSize(.small)
            } else {
                Button(paginationError == nil ? "Load more stories" : "Retry loading stories") {
                    Task {
                        await loadMore()
                    }
                }
                .clickableCursor()
                .disabled(isLoading)
                .accessibilityIdentifier("emptyFeed.loadMore")
            }
        }
        .padding(16)
        .task(id: paginationTrigger) {
            if paginationError == nil {
                await loadMore()
            }
        }
    }

    private var paginationFooter: some View {
        VStack(spacing: 8) {
            if let paginationError {
                Text(paginationError)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Retry Loading Stories") {
                    Task {
                        await loadMore()
                    }
                }
                .clickableCursor()
                .buttonStyle(.borderless)
            } else if isLoadingMore {
                ProgressView("Loading next 30 stories…")
                    .controlSize(.small)
            } else {
                Text("More stories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .listRowSeparator(.hidden)
        .id(rows.last?.id)
        .task(id: paginationTrigger) {
            if paginationError == nil {
                await loadMore()
            }
        }
    }

    private var paginationTrigger: FeedPaginationTrigger {
        FeedPaginationTrigger(revision: revision, isLoading: isLoading, nextOffset: nextOffset)
    }
}

#if DEBUG && os(macOS)
    struct ItemListPreview: View {
        enum PreviewState {
            case loaded
            case loading
            case emptySaved
            case emptyUnreadPage
            case error
            case loadingPage
            case pageError
        }

        let state: PreviewState

        @State private var selection: Int? = PreviewData.stories.first?.id
        @State private var unreadOnly = false

        init(state: PreviewState) {
            self.state = state
            _unreadOnly = State(initialValue: state == .emptyUnreadPage)
        }

        private var rows: [StoryRow] {
            switch state {
            case .loading, .emptySaved, .emptyUnreadPage, .error:
                return []

            case .loaded, .loadingPage, .pageError:
                return PreviewData.rows
            }
        }

        var body: some View {
            ItemList(
                rows: rows,
                revision: UUID(),
                nextOffset: rows.count,
                selectedID: $selection,
                title: state == .emptySaved ? "Saved" : "Top Stories",
                isLoading: state == .loading,
                isLoadingMore: state == .loadingPage,
                hasMore: state == .loadingPage || state == .pageError || state == .emptyUnreadPage,
                paginationError: state == .pageError ? "The next page couldn’t be loaded." : nil,
                errorMessage: state == .error
                    ? "You appear to be offline. Check your connection and try again." : nil,
                isSaved: state == .emptySaved,
                unreadOnly: $unreadOnly,
                refresh: {},
                loadMore: {}
            )
            .environment(PreviewData.appState(includeSavedStories: state != .emptySaved))
        }
    }

    #Preview("Story list · Light", traits: .fixedLayout(width: 560, height: 640)) {
        ItemListPreview(state: .loaded)
            .preferredColorScheme(.light)
    }

    #Preview("Story list · Dark", traits: .fixedLayout(width: 560, height: 640)) {
        ItemListPreview(state: .loaded)
            .preferredColorScheme(.dark)
    }

    #Preview("Story list · Loading", traits: .fixedLayout(width: 560, height: 640)) {
        ItemListPreview(state: .loading)
    }

    #Preview("Story list · Empty saved", traits: .fixedLayout(width: 560, height: 640)) {
        ItemListPreview(state: .emptySaved)
    }

    #Preview("Saved · Empty narrow", traits: .fixedLayout(width: 312, height: 640)) {
        ItemListPreview(state: .emptySaved)
            .preferredColorScheme(.dark)
    }

    #Preview("Story list · Empty unread page", traits: .fixedLayout(width: 312, height: 640)) {
        ItemListPreview(state: .emptyUnreadPage)
            .preferredColorScheme(.dark)
    }

    #Preview("Story list · Offline", traits: .fixedLayout(width: 560, height: 640)) {
        ItemListPreview(state: .error)
    }

    #Preview("Story list · Loading next page", traits: .fixedLayout(width: 560, height: 640)) {
        ItemListPreview(state: .loadingPage)
    }

    #Preview("Story list · Failed page", traits: .fixedLayout(width: 560, height: 640)) {
        ItemListPreview(state: .pageError)
    }

    #Preview("Story detail · Light", traits: .fixedLayout(width: 760, height: 820)) {
        if let item = PreviewData.stories.first {
            StoryDetail(
                item: item,
                initialComments: PreviewData.rootComments,
                previewThreads: PreviewData.threads,
                loadsAutomatically: false
            )
            .environment(PreviewData.appState())
            .preferredColorScheme(.light)
        }
    }

    #Preview("Story detail · Dark", traits: .fixedLayout(width: 760, height: 820)) {
        if let item = PreviewData.stories.first {
            StoryDetail(
                item: item,
                initialComments: PreviewData.rootComments,
                previewThreads: PreviewData.threads,
                loadsAutomatically: false
            )
            .environment(PreviewData.appState())
            .preferredColorScheme(.dark)
        }
    }

    #Preview("Story detail · Loading comments", traits: .fixedLayout(width: 760, height: 820)) {
        if let item = PreviewData.stories.first {
            StoryDetail(item: item, loadsAutomatically: false, isLoading: true)
                .environment(PreviewData.appState())
        }
    }

    #Preview("Story detail · No comments", traits: .fixedLayout(width: 760, height: 820)) {
        if let item = PreviewData.stories.first {
            StoryDetail(item: item, initialComments: [], loadsAutomatically: false)
                .environment(PreviewData.appState())
        }
    }

    #Preview("Story detail · Comment error", traits: .fixedLayout(width: 760, height: 820)) {
        if let item = PreviewData.stories.first {
            StoryDetail(
                item: item,
                loadsAutomatically: false,
                errorMessage: "Comments couldn’t be loaded. Please try again."
            )
            .environment(PreviewData.appState())
        }
    }
#endif

#if DEBUG && os(iOS)
    #Preview("iOS · Native Story List (Mock)") {
        IOSStoryListCanvas()
    }
#endif
