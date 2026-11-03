import SwiftUI

struct IOSHomeView: View {
    @State private var selectedFeed: AppState.SidebarSelection = .top

    var body: some View {
        TabView {
            IOSStoryList(selection: $selectedFeed, showsSavedStories: false)
                .tabItem {
                    Label("Stories", systemImage: "newspaper")
                }

            IOSStoryList(selection: .constant(.saved), showsSavedStories: true)
                .tabItem {
                    Label("Saved", systemImage: "bookmark")
                }
        }
        .tint(.orange)
    }
}

private struct IOSStoryList: View {
    @Environment(AppState.self) private var appState

    @Binding var selection: AppState.SidebarSelection
    let showsSavedStories: Bool

    @State private var viewModel = ItemListViewModel()
    @State private var searchText = ""
    @State private var unreadOnly = false

    private var rows: [StoryRow] {
        if showsSavedStories {
            return appState.savedItems.enumerated().map { index, item in
                StoryRow(rank: index + 1, item: item)
            }
        }

        return viewModel.rows
    }

    private var visibleRows: [StoryRow] {
        rows.filter { row in
            (!unreadOnly || !appState.readIDs.contains(row.id))
                && (
                    searchText.isEmpty
                        || [row.item.title, row.item.by, row.item.urlHost]
                            .compactMap { $0 }
                            .contains { $0.localizedCaseInsensitiveContains(searchText) }
                )
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage, !showsSavedStories {
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
                } else if viewModel.isLoading && visibleRows.isEmpty && !showsSavedStories {
                    ProgressView("Loading stories…")
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                } else if visibleRows.isEmpty {
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
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                }

                if !showsSavedStories && viewModel.hasMore && searchText.isEmpty {
                    paginationRow
                }
            }
            .listStyle(.plain)
            .navigationTitle(showsSavedStories ? "Saved Stories" : selection.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search stories")
            .toolbar {
                if !showsSavedStories {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("Feed", selection: $selection) {
                                ForEach(AppState.SidebarSelection.allCases.filter { $0 != .saved }) { feed in
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
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Refresh stories")
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            .refreshable {
                await refresh()
            }
            .navigationDestination(for: Item.self) { item in
                StoryDetail(item: item)
                    .environment(appState)
                    .navigationTitle("Story")
                    .navigationBarTitleDisplayMode(.inline)
                    .task {
                        appState.markRead(item)
                    }
            }
            .task(id: selection) {
                guard !showsSavedStories else { return }
                searchText = ""
                unreadOnly = false

                if let category = selection.category {
                    await viewModel.load(category)
                }
            }
        }
    }

    private var emptyTitle: String {
        if showsSavedStories { return "No saved stories" }
        return searchText.isEmpty ? "No stories yet" : "No matching stories"
    }

    private var emptyMessage: String {
        if showsSavedStories { return "Save a story to keep it here for later." }
        if !searchText.isEmpty { return "Try a different search." }
        if unreadOnly { return "Turn off Unread only to see stories you’ve read." }
        return "Pull down to refresh the feed."
    }

    @ViewBuilder
    private var paginationRow: some View {
        if viewModel.isLoadingMore {
            ProgressView("Loading more stories…")
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
        } else if let error = viewModel.paginationError {
            VStack(spacing: 8) {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await viewModel.loadMore() }
                }
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
        } else {
            Button("Load More Stories") {
                Task { await viewModel.loadMore() }
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
        }
    }

    private func refresh() async {
        guard !showsSavedStories, let category = selection.category else { return }
        await viewModel.load(category, forceRefresh: true)
    }
}

private struct IOSStoryRow: View {
    @Environment(AppState.self) private var appState

    let row: StoryRow

    private var isRead: Bool {
        appState.readIDs.contains(row.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Text("\(row.rank)")
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundStyle(.tertiary)

                Text(row.item.urlHost ?? "news.ycombinator.com")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 4)

                if !isRead {
                    Circle()
                        .fill(.orange)
                        .frame(width: 7, height: 7)
                        .accessibilityLabel("Unread")
                }

                if appState.isSaved(row.item) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Saved")
                }
            }

            Text(row.item.title ?? "Untitled story")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(isRead ? .secondary : .primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Label("\(row.item.score ?? 0)", systemImage: "arrowtriangle.up.fill")
                Label("\(row.item.descendants ?? 0)", systemImage: "bubble.right")
                if let author = row.item.by {
                    Text("by \(author)")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 4)
                Text(row.item.timeStringRepresentation.map { "\($0) ago" } ?? "")
                    .lineLimit(1)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button(appState.isSaved(row.item) ? "Remove from Saved" : "Save for Later", systemImage: "bookmark") {
                appState.toggleSaved(row.item)
            }
            Link("Open Article", destination: row.item.articleURL ?? row.item.discussionURL)
            Link("Open Discussion", destination: row.item.discussionURL)
            ShareLink(item: row.item.articleURL ?? row.item.discussionURL)
        }
    }
}

#if DEBUG
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
        .tint(.orange)
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
            guard let loaded = try await NewsService.shared.item(
                id: Self.storyID,
                forceRefresh: true
            ) else {
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
