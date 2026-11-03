import SwiftUI

struct ItemList: View {
    let rows: [StoryRow]
    let revision: UUID

    @Binding var selectedID: Int?

    let title: String
    let subtitle: String
    let isLoading: Bool
    let isLoadingMore: Bool
    let hasMore: Bool
    let paginationError: String?
    let errorMessage: String?
    let isSaved: Bool
    let isSearching: Bool

    @Binding var unreadOnly: Bool

    let refresh: () async -> Void
    let loadMore: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("\(rows.count) stories")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Toggle("Unread only", isOn: $unreadOnly)
                        .clickableCursor()
                        .toggleStyle(.button)
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .help("Show only stories you haven’t read")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

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
                            .help(row.item.title ?? "")
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
            Image(systemName: isSaved ? "bookmark" : "magnifyingglass")
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
        if isSearching {
            return ("No matching stories", "Try a different search.")
        }

        if unreadOnly {
            if canLoadMore {
                return ("No unread stories in loaded pages", "Load more stories to look for unread items.")
            }

            return ("No unread stories", "Turn off Unread only to see stories you’ve read.")
        }

        if isSaved {
            return ("No saved stories", "Use the bookmark button to save a story.")
        }

        let description = canLoadMore ? "Load more stories to continue." : "Refresh to check for stories."

        return ("No stories to show", description)
    }

    private var canLoadMore: Bool {
        hasMore && !isSaved && !isSearching
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
        .task(id: revision) {
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
        .task(id: revision) {
            if paginationError == nil {
                await loadMore()
            }
        }
    }

}

struct StoryDetail: View {
    @State private var model: StoryDetailViewModel

    @Environment(AppState.self) private var appState

    @State private var threadsCollapsed = false
    @State private var commentFrames: [Int: CGRect] = [:]
    @State private var commentViewportHeight: CGFloat = 0
    @State private var pendingCommentID: Int?

    private let previewThreads: [Int: [Item]]?
    private let loadsAutomatically: Bool

    init(
        item: Item,
        initialComments: [Item]? = nil,
        previewThreads: [Int: [Item]]? = nil,
        loadsAutomatically: Bool = true,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.previewThreads = previewThreads
        self.loadsAutomatically = loadsAutomatically
        _model = State(initialValue: StoryDetailViewModel(
            item: item,
            initialComments: initialComments,
            isLoading: isLoading,
            errorMessage: errorMessage
        ))
    }

    private var item: Item {
        model.item
    }

    private var navigation: CommentNavigation {
        CommentNavigation(
            ids: model.comments.map(\.id),
            frames: commentFrames,
            viewportHeight: commentViewportHeight
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(item.urlHost?.uppercased() ?? "HACKER NEWS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(.orange)

                        Text(item.title ?? "Untitled story")
                            .font(.system(size: 30, weight: .semibold, design: .serif))
                            .textSelection(.enabled)

                        #if os(macOS)
                        HStack(spacing: 8) {
                            Text(item.by ?? "Unknown author")

                            Text("·")

                            Text("\(item.timeStringRepresentation ?? "") ago")

                            Text("·")

                            Text("\(item.score ?? 0) points")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        #else
                        HStack(spacing: 14) {
                            Label {
                                Text("\(item.score ?? 0) points")
                            } icon: {
                                Image(systemName: "arrow.up")
                                    .fontWeight(.bold)
                            }

                            if let time = item.timeStringRepresentation {
                                Label {
                                    Text("\(time) ago")
                                } icon: {
                                    Image(systemName: "calendar")
                                        .fontWeight(.bold)
                                }
                            }

                            Label {
                                Text(item.by ?? "Unknown author")
                            } icon: {
                                Image(systemName: "person")
                                    .fontWeight(.bold)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .accessibilityElement(children: .combine)
                        #endif

                        #if os(macOS)
                        HStack(spacing: 12) {
                            Link(destination: item.articleURL ?? item.discussionURL) {
                                Label(
                                    "Open \(item.articleURL == nil ? "on Hacker News" : "Article")",
                                    systemImage: "arrow.up.right"
                                )
                            }
                            .clickableCursor()
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)

                            Button {
                                appState.toggleSaved(item)
                            } label: {
                                Label(
                                    appState.isSaved(item) ? "Saved" : "Save for Later",
                                    systemImage: appState.isSaved(item) ? "bookmark.fill" : "bookmark"
                                )
                            }
                            .clickableCursor()
                            .buttonStyle(.bordered)
                        }
                        #endif
                    }

                    if let text = item.text, !text.isEmpty {
                        #if os(macOS)
                        HTMLText(text: text)
                        #else
                        HTMLText(text: text, fontSize: 17, lineSpacing: 6)
                        #endif
                    }

                    #if os(macOS)
                    HStack {
                        Label("Discussion", systemImage: "bubble.left.and.bubble.right")
                            .font(.headline)

                        Text("\(item.descendants ?? 0)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            threadsCollapsed.toggle()
                        } label: {
                            Label(
                                threadsCollapsed ? "Expand threads" : "Collapse threads",
                                systemImage: threadsCollapsed ? "chevron.down" : "chevron.up"
                            )
                        }
                        .clickableCursor()
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                        Link("View on HN", destination: item.discussionURL)
                            .clickableCursor()
                            .font(.system(size: 10))
                    }
                    #else
                    HStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.title3.weight(.semibold))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Discussion")
                                .font(.headline)

                            Text("\(item.descendants ?? 0) comments")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Button {
                                threadsCollapsed.toggle()
                            } label: {
                                Image(systemName: threadsCollapsed ? "chevron.down" : "chevron.up")
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(threadsCollapsed ? "Expand threads" : "Collapse threads")

                            Link(destination: item.discussionURL) {
                                Label("View on HN", systemImage: "safari")
                                    .frame(minHeight: 36)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("View discussion on Hacker News")
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                    #endif

                    if model.comments.isEmpty && !model.isLoading && model.errorMessage == nil {
                        Text("No comments yet. Be the first to join the conversation on Hacker News.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical)
                    }

                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.comments) { comment in
                            CommentView(
                                item: comment,
                                storyAuthor: item.by,
                                collapseAll: threadsCollapsed,
                                previewThreads: previewThreads
                            )
                            .id(comment.id)
                            #if os(macOS)
                            .background {
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: CommentPositions.self,
                                        value: [comment.id: geometry.frame(in: .named("discussionScroll"))]
                                    )
                                }
                            }
                            #endif
                        }
                    }

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Retry Comments") {
                            Task {
                                await model.loadComments()
                            }
                        }
                        .clickableCursor()
                    }

                    if model.isLoading {
                        ProgressView("Loading conversation…")
                            .frame(maxWidth: .infinity)
                    } else if model.hasMoreComments && model.errorMessage == nil {
                        Button("Load More Comments") {
                            Task {
                                await model.loadComments()
                            }
                        }
                        .clickableCursor()
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                #if os(macOS)
                .padding(32)
                #else
                .padding(16)
                #endif
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
            #if os(macOS)
            .coordinateSpace(name: "discussionScroll")
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.containerSize.height
            } action: { _, height in
                commentViewportHeight = height
            }
            .onPreferenceChange(CommentPositions.self) { frames in
                commentFrames = frames
            }
            .onChange(of: pendingCommentID) { _, id in
                guard let id else {
                    return
                }

                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(id, anchor: .top)
                }

                pendingCommentID = nil
            }
            .overlay(alignment: .bottomTrailing) {
                if !model.comments.isEmpty {
                    CommentJumpControls(
                        canGoUp: navigation.target(for: .previous) != nil,
                        canGoDown: navigation.target(for: .next) != nil || model.hasMoreComments,
                        isLoading: model.isLoading,
                        previous: {
                            pendingCommentID = navigation.target(for: .previous)
                        },
                        next: {
                            Task {
                                await jumpToNextComment()
                            }
                        }
                    )
                    .padding(.trailing, 24)
                    .padding(.bottom, 20)
                }
            }
            #endif
        }
        .background(PlatformColors.textBackground)
        .toolbar {
            Button {
                appState.toggleSaved(item)
            } label: {
                Label(
                    appState.isSaved(item) ? "Remove from Saved" : "Save Story",
                    systemImage: appState.isSaved(item) ? "bookmark.fill" : "bookmark"
                )
            }
            .clickableCursor()
            .keyboardShortcut("d", modifiers: .command)

            ShareLink(item: item.articleURL ?? item.discussionURL)
                .clickableCursor()
        }
        .task {
            if loadsAutomatically {
                await model.loadComments()
            }
        }
    }

    @MainActor
    private func jumpToNextComment() async {
        if let id = navigation.target(for: .next) {
            pendingCommentID = id
            return
        }

        guard loadsAutomatically, model.hasMoreComments, !model.isLoading else {
            return
        }

        let previousCount = model.comments.count
        await model.loadComments()

        if model.comments.count > previousCount {
            pendingCommentID = model.comments[previousCount].id
        }
    }
}

#if DEBUG && os(macOS)
struct ItemListPreview: View {
    enum PreviewState {
        case loaded
        case loading
        case emptySaved
        case emptyUnreadPage
        case noResults
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
        case .loading, .emptySaved, .emptyUnreadPage, .noResults, .error:
            return []

        case .loaded, .loadingPage, .pageError:
            return PreviewData.rows
        }
    }

    var body: some View {
        ItemList(
            rows: rows,
            revision: UUID(),
            selectedID: $selection,
            title: state == .emptySaved ? "Saved" : "Top Stories",
            subtitle: state == .emptySaved ? "Good reads, kept for later" : "What the community is reading",
            isLoading: state == .loading,
            isLoadingMore: state == .loadingPage,
            hasMore: state == .loadingPage || state == .pageError || state == .emptyUnreadPage,
            paginationError: state == .pageError ? "The next page couldn’t be loaded." : nil,
            errorMessage: state == .error ? "You appear to be offline. Check your connection and try again." : nil,
            isSaved: state == .emptySaved,
            isSearching: state == .noResults,
            unreadOnly: $unreadOnly,
            refresh: {},
            loadMore: {}
        )
        .environment(PreviewData.appState(includeSavedStories: state != .emptySaved))
        .tint(.orange)
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

#Preview("Story list · No search results", traits: .fixedLayout(width: 560, height: 640)) {
    ItemListPreview(state: .noResults)
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
        .tint(.orange)
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
        .tint(.orange)
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
