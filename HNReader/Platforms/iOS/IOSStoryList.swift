import SwiftUI

private struct IOSPlainBackground: View {
    var body: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct IOSStoryHeader: View {
    @Binding var selection: AppState.SidebarSelection
    let showsSavedStories: Bool
    let isLoading: Bool
    @Binding var unreadOnly: Bool
    @Binding var showsSettings: Bool
    let refresh: () async -> Void

    var body: some View {
        HStack(spacing: 14) {
            if showsSavedStories {
                Text("Saved")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Menu {
                    Picker("Feed", selection: $selection) {
                        ForEach(AppState.SidebarSelection.allCases.filter { $0 != .saved }) { feed in
                            Label(feed.rawValue, systemImage: feed.iconName).tag(feed)
                        }
                    }
                    Divider()
                    Toggle("Unread only", isOn: $unreadOnly)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selection.iconName)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color(hue: 0.06, saturation: 0.88, brightness: 0.78))
                        Text(selection.rawValue)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 44, alignment: .leading)
                }
                .accessibilityLabel("Choose story feed and filters")
                .tint(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                showsSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
            .tint(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

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
    @State private var unreadOnly = false
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
        rows.filter { !unreadOnly || !appState.readIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                IOSPlainBackground()

                ScrollViewReader { _ in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            IOSStoryHeader(
                                selection: $selection,
                                showsSavedStories: showsSavedStories,
                                isLoading: isLoading,
                                unreadOnly: $unreadOnly,
                                showsSettings: $showsSettings,
                                refresh: refresh
                            )

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
                        .padding(.horizontal, 24)
                    }
                    if isLoading && visibleRows.isEmpty && !showsSavedStories {
                        ProgressView("Loading stories…")
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 24)
                    } else if visibleRows.isEmpty && errorMessage == nil {
                        ContentUnavailableView(
                            emptyTitle,
                            systemImage: showsSavedStories ? "bookmark" : "newspaper",
                            description: Text(emptyMessage)
                        )
                        .padding(.horizontal, 24)
                    } else {
                        ForEach(visibleRows) { row in
                            VStack(spacing: 0) {
                                Button {
                                    navigationPath.append(row.item)
                                } label: {
                                    IOSStoryRow(row: row)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(row.id)

                                if row.id != visibleRows.last?.id {
                                    Divider()
                                        .padding(.horizontal, 24)
                                        .opacity(0.45)
                                }
                            }
                        }
                    }

                    if !showsSavedStories && feed.hasMore {
                        paginationRow
                    }
                        }
                        .padding(.bottom, 128)
                    }
                    .offset(y: -20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
                unreadOnly = false

                if selection.category != nil {
                    await loadFeed()
                    guard !Task.isCancelled else { return }
                }
            }
        }
    }

    private var emptyTitle: String {
        if unreadOnly { return showsSavedStories ? "No unread saved items" : "No unread stories" }
        if showsSavedStories { return "No saved items" }
        return "No stories yet"
    }

    private var emptyMessage: String {
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
