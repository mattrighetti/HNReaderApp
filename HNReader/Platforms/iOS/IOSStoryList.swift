import SwiftUI

struct IOSStoryList: View {
    @Environment(AppState.self) private var appState

    @Binding var selection: AppState.SidebarSelection
    private let showsSavedStories: Bool
    private let loadsAutomatically: Bool
    private let previewComments: [Item]?
    private let previewThreads: [Int: [Item]]?

    @State private var feed: FeedPage
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var paginationError: String?
    @State private var revision = UUID()
    private let repository: FeedRepository
    @State private var searchText = ""
    @State private var unreadOnly = false
    @State private var scrollResetRequest = UUID()
    @State private var navigationPath: [Item] = []
    @State private var showsSettings = false

    @MainActor
    init(
        selection: Binding<AppState.SidebarSelection>,
        showsSavedStories: Bool
    ) {
        _selection = selection
        self.showsSavedStories = showsSavedStories
        loadsAutomatically = true
        previewComments = nil
        previewThreads = nil
        _feed = State(initialValue: FeedPage())
        repository = .shared
    }

    @MainActor
    init(
        selection: Binding<AppState.SidebarSelection>,
        showsSavedStories: Bool,
        initialRows: [StoryRow] = [],
        repository: FeedRepository = .shared,
        loadsAutomatically: Bool,
        previewComments: [Item]?,
        previewThreads: [Int: [Item]]?
    ) {
        _selection = selection
        self.showsSavedStories = showsSavedStories
        self.loadsAutomatically = loadsAutomatically
        self.previewComments = previewComments
        self.previewThreads = previewThreads
        _feed = State(initialValue: .preview(initialRows))
        self.repository = repository
    }

    private var rows: [StoryRow] {
        if showsSavedStories {
            return StoryRow.savedRows(for: appState.savedItems)
        }

        return feed.rows
    }

    private var visibleRows: [StoryRow] {
        rows.filter { row in
            (!unreadOnly || !appState.readIDs.contains(row.id))
                && (searchText.isEmpty
                    || [
                        row.item.title, row.item.by, row.item.urlHost,
                        row.item.type == .comment ? row.item.text : nil,
                    ]
                    .compactMap { $0 }
                    .contains { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollViewReader { proxy in
                List {
                    if let errorMessage = errorMessage, !showsSavedStories {
                        ContentUnavailableView {
                            Label("Couldn’t load stories", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(errorMessage)
                        } actions: {
                            Button("Try Again") {
                                Task { await refresh() }
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                    if isLoading && visibleRows.isEmpty && !showsSavedStories {
                        ProgressView("Loading stories…")
                            .frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                    } else if visibleRows.isEmpty && errorMessage == nil {
                        ContentUnavailableView(
                            emptyTitle,
                            systemImage: showsSavedStories ? "bookmark" : "newspaper",
                            description: Text(emptyMessage)
                        )
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(visibleRows) { row in
                            NavigationLink(value: row.item) {
                                IOSStoryRow(row: row)
                            }
                            .listRowInsets(
                                EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
                            )
                            .id(row.id)
                        }
                    }

                    if !showsSavedStories && feed.hasMore && searchText.isEmpty {
                        paginationRow
                    }
                }
                .listStyle(.plain)
                // Keep feed changes and page inserts out of the menu's animation.
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
                .onChange(of: scrollResetRequest) {
                    if let firstID = visibleRows.first?.id {
                        proxy.scrollTo(firstID, anchor: .top)
                    }
                }
            }
            .navigationTitle(showsSavedStories ? "Saved" : selection.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText,
                prompt: showsSavedStories ? "Search saved items" : "Search stories"
            )
            .toolbar {
                if !showsSavedStories {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("Feed", selection: $selection) {
                                ForEach(AppState.SidebarSelection.allCases.filter { $0 != .saved })
                                { feed in
                                    Label(feed.rawValue, systemImage: feed.iconName)
                                        .tag(feed)
                                }
                            }

                            Divider()

                            Toggle("Unread only", isOn: $unreadOnly)
                        } label: {
                            Label(selection.rawValue, systemImage: selection.iconName)
                                .labelStyle(.iconOnly)
                        }
                        .accessibilityLabel("Choose story feed and filters")
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Toggle(isOn: $unreadOnly) {
                            Label("Unread only", systemImage: "circle.lefthalf.filled")
                        }
                        .labelsHidden()
                    }
                }

                if !showsSavedStories {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await refresh() }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .frame(width: 20, height: 20)
                        }
                        .accessibilityLabel(isLoading ? "Refreshing stories" : "Refresh stories")
                        .disabled(isLoading)
                    }
                }

                if !showsSavedStories && navigationPath.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showsSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
            }
            .refreshable {
                await refresh()
            }
            .navigationDestination(for: Item.self) { item in
                Group {
                    if item.type == .comment {
                        SavedCommentDetail(item: item, previewThreads: previewThreads)
                    } else {
                        StoryDetail(
                            item: item,
                            initialComments: previewComments,
                            previewThreads: previewThreads,
                            loadsAutomatically: loadsAutomatically
                        )
                    }
                }
                .environment(appState)
                .navigationTitle(item.type == .comment ? "Saved Comment" : "Story")
                .navigationBarTitleDisplayMode(.inline)
                .task {
                    appState.markRead(item)
                }
            }
            .sheet(isPresented: $showsSettings) {
                IOSSettingsView()
            }
            .task(id: selection) {
                guard loadsAutomatically, !showsSavedStories else { return }
                searchText = ""
                unreadOnly = false

                if selection.category != nil {
                    await loadFeed()
                    guard !Task.isCancelled else { return }
                    scrollResetRequest = UUID()
                }
            }
        }
    }

    private var emptyTitle: String {
        if !searchText.isEmpty {
            return showsSavedStories ? "No matching saved items" : "No matching stories"
        }
        if unreadOnly { return showsSavedStories ? "No unread saved items" : "No unread stories" }
        if showsSavedStories { return "No saved items" }
        return "No stories yet"
    }

    private var emptyMessage: String {
        if !searchText.isEmpty { return "Try a different search." }
        if unreadOnly {
            return showsSavedStories
                ? "Turn off Unread only to see saved items you’ve read."
                : "Turn off Unread only to see stories you’ve read."
        }
        if showsSavedStories { return "Save a story or comment to keep it here for later." }
        return "Pull down to refresh the feed."
    }

    private var paginationRow: some View {
        VStack(spacing: 8) {
            if let error = paginationError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await loadMore() }
                }
            } else if isLoadingMore {
                ProgressView("Loading more stories…")
            } else {
                Text("More stories")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .listRowSeparator(.hidden)
        .id(feed.rows.last?.id)
        .task(
            id: FeedPaginationTrigger(
                revision: revision, isLoading: isLoading, nextOffset: feed.nextOffset)
        ) {
            guard loadsAutomatically, paginationError == nil else { return }
            await loadMore()
        }
    }

    @MainActor
    private func loadFeed(forceRefresh: Bool = false) async {
        guard let category = selection.category, !Task.isCancelled else { return }
        revision = UUID()
        let request = revision
        isLoading = true
        isLoadingMore = false
        errorMessage = nil
        paginationError = nil
        defer { if revision == request { isLoading = false } }

        if let cached = await repository.cached(category) {
            guard revision == request, !Task.isCancelled else { return }
            feed = cached
        } else {
            guard revision == request, !Task.isCancelled else { return }
            feed = FeedPage()
        }

        do {
            let result = try await repository.feed(category, forceRefresh: forceRefresh)
            guard revision == request, selection.category == category, !Task.isCancelled else {
                return
            }
            feed = result
        } catch {
            guard revision == request, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadMore() async {
        guard loadsAutomatically, !isLoading, !isLoadingMore, feed.hasMore,
            let category = selection.category, !Task.isCancelled
        else { return }
        let request = revision
        isLoadingMore = true
        paginationError = nil
        defer { if revision == request { isLoadingMore = false } }
        do {
            let result = try await repository.nextPage(after: feed, category: category)
            guard revision == request, selection.category == category, !Task.isCancelled else {
                return
            }
            feed = result
        } catch {
            guard revision == request, !Task.isCancelled else { return }
            paginationError = error.localizedDescription
        }
    }

    private func refresh() async {
        guard loadsAutomatically, !showsSavedStories, selection.category != nil else { return }
        await loadFeed(forceRefresh: true)
    }
}
