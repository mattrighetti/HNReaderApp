import SwiftUI

struct StoryRow: Identifiable {
    let rank: Int
    let item: Item

    var id: Int {
        item.id
    }
}

@MainActor
final class ItemListViewModel: ObservableObject {
    @Published private(set) var rows: [StoryRow] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var paginationError: String?
    @Published private(set) var revision = UUID()

    var stories: [Item] {
        rows.map(\.item)
    }

    private struct FeedSnapshot {
        let ids: [Int]
        let rows: [StoryRow]
        let nextOffset: Int
        let fetchedAt: Date
    }

    private let pageSize = 30
    private let service: NewsService
    private let now: @Sendable () -> Date
    private let feedLifetime: TimeInterval

    private var feeds: [HackerNews.API.Stories: FeedSnapshot] = [:]
    private var currentCategory: HackerNews.API.Stories?
    private var storyIDs: [Int] = []
    private var nextOffset = 0

    init(
        service: NewsService = .shared,
        feedLifetime: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = service
        self.feedLifetime = feedLifetime
        self.now = now
    }

    func load(_ category: HackerNews.API.Stories, forceRefresh: Bool = false) async {
        guard !Task.isCancelled else {
            return
        }

        revision = UUID()
        let request = revision
        let cached = feeds[category]

        currentCategory = category
        rows = cached?.rows ?? []
        storyIDs = cached?.ids ?? []
        nextOffset = cached?.nextOffset ?? 0
        hasMore = nextOffset < storyIDs.count
        errorMessage = nil
        paginationError = nil
        isLoading = false
        isLoadingMore = false

        if let cached, !forceRefresh, now().timeIntervalSince(cached.fetchedAt) < feedLifetime {
            return
        }

        isLoading = true

        defer {
            if revision == request {
                isLoading = false
            }
        }

        do {
            let response = try await service.storyIDs(for: category, forceRefresh: forceRefresh)
            var seen: Set<Int> = []
            let ids = response.filter { seen.insert($0).inserted }
            let pageIDs = Array(ids.prefix(pageSize))

            let items = try await service.items(ids: pageIDs, forceRefresh: forceRefresh)
            try Task.checkCancellation()

            guard revision == request else {
                return
            }

            storyIDs = ids
            nextOffset = pageIDs.count
            rows = makeRows(ids: pageIDs, items: items, offset: 0)
            hasMore = nextOffset < ids.count

            saveFeed(category, fetchedAt: now())
        } catch {
            guard revision == request, !Task.isCancelled else {
                return
            }

            errorMessage = error.localizedDescription
        }
    }

    /// Commit one complete page. A failed or cancelled page leaves existing rows untouched.
    func loadMore() async {
        guard
            !Task.isCancelled,
            !isLoading,
            !isLoadingMore,
            hasMore,
            let category = currentCategory
        else {
            return
        }

        let request = revision
        let offset = nextOffset
        let pageIDs = Array(storyIDs.dropFirst(offset).prefix(pageSize))
        let fetchedAt = feeds[category]?.fetchedAt ?? now()

        isLoadingMore = true
        paginationError = nil

        defer {
            if revision == request {
                isLoadingMore = false
            }
        }

        do {
            let items = try await service.items(ids: pageIDs)
            try Task.checkCancellation()

            guard revision == request else {
                return
            }

            rows += makeRows(ids: pageIDs, items: items, offset: offset)
            nextOffset += pageIDs.count
            hasMore = nextOffset < storyIDs.count

            saveFeed(category, fetchedAt: fetchedAt)
        } catch {
            guard revision == request, !Task.isCancelled else {
                return
            }

            paginationError = error.localizedDescription
        }
    }

    func deactivate() {
        revision = UUID()
        currentCategory = nil
        isLoading = false
        isLoadingMore = false
    }

    private func makeRows(ids: [Int], items: [Item], offset: Int) -> [StoryRow] {
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        return ids.enumerated().compactMap { index, id in
            guard let item = itemsByID[id], item.deleted != true, item.dead != true else {
                return nil
            }

            return StoryRow(rank: offset + index + 1, item: item)
        }
    }

    private func saveFeed(_ category: HackerNews.API.Stories, fetchedAt: Date) {
        feeds[category] = FeedSnapshot(
            ids: storyIDs,
            rows: rows,
            nextOffset: nextOffset,
            fetchedAt: fetchedAt
        )
    }
}
