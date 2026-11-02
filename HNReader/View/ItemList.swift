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
                ContentUnavailableView {
                    Label(
                        isSaved ? "Your reading list awaits" : "No stories to show",
                        systemImage: isSaved ? "bookmark" : "magnifyingglass"
                    )
                } description: {
                    Text(
                        isSearching
                            ? "Try a different search."
                            : unreadOnly
                            ? "You’re all caught up. Turn off the unread filter to see more."
                            : isSaved
                            ? "Save a story to come back to it later."
                            : "Refresh to check for stories."
                    )
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

                    if hasMore && !isSaved && !isSearching {
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
        .background(Color(nsColor: .controlBackgroundColor))
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
    let item: Item

    @EnvironmentObject private var appState: AppState

    @State private var comments: [Item] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loadedCount = 0
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
        self.item = item
        self.previewThreads = previewThreads
        self.loadsAutomatically = loadsAutomatically
        _comments = State(initialValue: initialComments ?? [])
        _loadedCount = State(initialValue: initialComments == nil ? 0 : item.kids?.count ?? 0)
        _isLoading = State(initialValue: isLoading)
        _errorMessage = State(initialValue: errorMessage)
    }

    private var navigation: CommentNavigation {
        CommentNavigation(
            ids: comments.map(\.id),
            frames: commentFrames,
            viewportHeight: commentViewportHeight
        )
    }

    private var hasMoreComments: Bool {
        loadedCount < (item.kids?.count ?? 0)
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

                        HStack(spacing: 8) {
                            Text(item.by ?? "Unknown author")

                            Text("·")

                            Text("\(item.timeStringRepresentation ?? "") ago")

                            Text("·")

                            Text("\(item.score ?? 0) points")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

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
                    }

                    if let text = item.text, !text.isEmpty {
                        HTMLText(text: text)
                    }

                    Divider()

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

                    if comments.isEmpty && !isLoading && errorMessage == nil {
                        Text("No comments yet. Be the first to join the conversation on Hacker News.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical)
                    }

                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(comments) { comment in
                            CommentView(
                                item: comment,
                                storyAuthor: item.by,
                                collapseAll: threadsCollapsed,
                                previewThreads: previewThreads
                            )
                            .id(comment.id)
                            .background {
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: CommentPositions.self,
                                        value: [comment.id: geometry.frame(in: .named("discussionScroll"))]
                                    )
                                }
                            }

                            Divider()
                                .padding(.vertical, 4)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Retry Comments") {
                            Task {
                                await loadComments()
                            }
                        }
                        .clickableCursor()
                    }

                    if isLoading {
                        ProgressView("Loading conversation…")
                            .frame(maxWidth: .infinity)
                    } else if loadedCount < (item.kids?.count ?? 0) && errorMessage == nil {
                        Button("Load More Comments") {
                            Task {
                                await loadComments()
                            }
                        }
                        .clickableCursor()
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(32)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
            .coordinateSpace(name: "discussionScroll")
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: CommentViewportHeight.self,
                        value: geometry.size.height
                    )
                }
            }
            .onPreferenceChange(CommentPositions.self) { frames in
                commentFrames = frames
            }
            .onPreferenceChange(CommentViewportHeight.self) { height in
                commentViewportHeight = height
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
                if !comments.isEmpty {
                    CommentJumpControls(
                        canGoUp: navigation.target(for: .previous) != nil,
                        canGoDown: navigation.target(for: .next) != nil || hasMoreComments,
                        isLoading: isLoading,
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
        }
        .background(Color(nsColor: .textBackgroundColor))
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
                await loadComments()
            }
        }
    }

    @MainActor
    private func jumpToNextComment() async {
        if let id = navigation.target(for: .next) {
            pendingCommentID = id
            return
        }

        guard loadsAutomatically, hasMoreComments, !isLoading else {
            return
        }

        let previousCount = comments.count
        await loadComments()

        if comments.count > previousCount {
            pendingCommentID = comments[previousCount].id
        }
    }

    @MainActor private func loadComments() async {
        guard loadsAutomatically, !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let ids = Array((item.kids ?? []).dropFirst(loadedCount).prefix(20))
            let result = try await NewsService.shared.items(ids: ids)
            try Task.checkCancellation()

            comments += result
            loadedCount += ids.count
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#if DEBUG
struct ItemListPreview: View {
    enum PreviewState {
        case loaded
        case loading
        case emptySaved
        case noResults
        case error
        case loadingPage
        case pageError
    }

    let state: PreviewState

    @State private var selection: Int? = PreviewData.stories.first?.id
    @State private var unreadOnly = false

    private var rows: [StoryRow] {
        switch state {
        case .loading, .emptySaved, .noResults, .error:
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
            hasMore: state == .loadingPage || state == .pageError,
            paginationError: state == .pageError ? "The next page couldn’t be loaded." : nil,
            errorMessage: state == .error ? "You appear to be offline. Check your connection and try again." : nil,
            isSaved: state == .emptySaved,
            isSearching: state == .noResults,
            unreadOnly: $unreadOnly,
            refresh: {},
            loadMore: {}
        )
        .environmentObject(PreviewData.appState(includeSavedStories: state != .emptySaved))
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

#Preview("Story list · No search results", traits: .fixedLayout(width: 560, height: 640)) {
    ItemListPreview(state: .noResults)
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
        .environmentObject(PreviewData.appState())
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
        .environmentObject(PreviewData.appState())
        .preferredColorScheme(.dark)
        .tint(.orange)
    }
}

#Preview("Story detail · Loading comments", traits: .fixedLayout(width: 760, height: 820)) {
    if let item = PreviewData.stories.first {
        StoryDetail(item: item, loadsAutomatically: false, isLoading: true)
            .environmentObject(PreviewData.appState())
    }
}

#Preview("Story detail · No comments", traits: .fixedLayout(width: 760, height: 820)) {
    if let item = PreviewData.stories.first {
        StoryDetail(item: item, initialComments: [], loadsAutomatically: false)
            .environmentObject(PreviewData.appState())
    }
}

#Preview("Story detail · Comment error", traits: .fixedLayout(width: 760, height: 820)) {
    if let item = PreviewData.stories.first {
        StoryDetail(
            item: item,
            loadsAutomatically: false,
            errorMessage: "Comments couldn’t be loaded. Please try again."
        )
        .environmentObject(PreviewData.appState())
    }
}
#endif
