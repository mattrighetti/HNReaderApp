import SwiftUI

#if os(macOS)
    struct MacReaderView: View {
        @Environment(AppState.self) private var appState

        @State private var feed: FeedPage
        @State private var isLoading = false
        @State private var isLoadingMore = false
        @State private var errorMessage: String?
        @State private var paginationError: String?
        @State private var revision = UUID()
        private let repository: FeedRepository
        @State private var sidebarSelection: AppState.SidebarSelection?

        @State private var selectedID: Int?
        @State private var unreadOnly = false
        @State private var columnVisibility: NavigationSplitViewVisibility = .all

        private let loadsAutomatically: Bool
        private let previewComments: [Item]?
        private let previewThreads: [Int: [Item]]?

        init(
            initialRows: [StoryRow] = [],
            initialSelection: AppState.SidebarSelection = .top,
            initialUnreadOnly: Bool = false,
            repository: FeedRepository = .shared,
            selectedID: Int? = nil,
            loadsAutomatically: Bool = true,
            previewComments: [Item]? = nil,
            previewThreads: [Int: [Item]]? = nil
        ) {
            _feed = State(initialValue: .preview(initialRows))
            _sidebarSelection = State(initialValue: initialSelection)
            _unreadOnly = State(initialValue: initialUnreadOnly)
            self.repository = repository
            _selectedID = State(initialValue: selectedID)
            self.loadsAutomatically = loadsAutomatically
            self.previewComments = previewComments
            self.previewThreads = previewThreads
        }

        private var selection: AppState.SidebarSelection {
            sidebarSelection ?? .top
        }

        private var source: [Item] {
            selection == .saved ? appState.savedItems : feed.items
        }

        private var selectedItem: Item? {
            (source + appState.savedItems).first { $0.id == selectedID }
        }

        private var visibleRows: [StoryRow] {
            let rows =
                selection == .saved
                ? StoryRow.savedRows(for: appState.savedItems)
                : feed.rows

            return rows.filter {
                !unreadOnly || !appState.readIDs.contains($0.id) || $0.id == selectedID
            }
        }

        var body: some View {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                Sidebar(selection: $sidebarSelection)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 260)
            } content: {
                ItemList(
                    rows: visibleRows,
                    revision: revision,
                    nextOffset: feed.nextOffset,
                    selectedID: $selectedID,
                    title: selection.rawValue,
                    isLoading: selection != .saved && isLoading,
                    isLoadingMore: selection != .saved && isLoadingMore,
                    hasMore: selection != .saved && feed.hasMore,
                    paginationError: selection == .saved ? nil : paginationError,
                    errorMessage: selection == .saved ? nil : errorMessage,
                    isSaved: selection == .saved,
                    unreadOnly: $unreadOnly,
                    refresh: refresh,
                    loadMore: {
                        if loadsAutomatically {
                            await loadMore()
                        }
                    }
                )
                #if os(macOS)
                    .frame(minWidth: 312)
                #endif
                .navigationSplitViewColumnWidth(min: 312, ideal: 312, max: 720)
                #if os(macOS)
                    .background {
                        SplitColumnWidth(minimum: 312, maximum: 720)
                        .allowsHitTesting(false)
                    }
                #endif
            } detail: {
                NavigationStack {
                    if let item = selectedItem {
                        if item.type == .comment {
                            SavedCommentDetail(item: item, previewThreads: previewThreads)
                        } else {
                            StoryDetail(
                                item: item,
                                initialComments: previewComments,
                                previewThreads: previewThreads,
                                loadsAutomatically: loadsAutomatically
                            )
                            .id(item.id)
                        }
                    } else {
                        ContentUnavailableView("Select a story", systemImage: "newspaper")
                    }
                }
                .id(selectedItem?.id)
            }
            .navigationSplitViewStyle(.balanced)
            .task(id: selection) {
                guard loadsAutomatically else {
                    return
                }

                selectedID = nil
                if selection.category != nil {
                    await loadFeed()
                } else {
                    revision = UUID()
                    isLoading = false
                    isLoadingMore = false
                }
            }
            .onChange(of: selectedItem?.id) { _, _ in
                if let item = selectedItem {
                    appState.markRead(item)
                }
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
            guard loadsAutomatically else {
                return
            }

            if selection.category != nil {
                await loadFeed(forceRefresh: true)
            }
        }
    }

#endif
