import Foundation

/// Shared feed data/cache, independent of any screen's selection or presentation state.
actor FeedRepository {
    static let shared = FeedRepository()

    private let service: NewsService
    private let lifetime: TimeInterval
    private let now: @Sendable () -> Date
    private var feeds: [HackerNews.API.Stories: FeedPage] = [:]
    private var generations: [HackerNews.API.Stories: UUID] = [:]

    init(
        service: NewsService = .shared, lifetime: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = service
        self.lifetime = lifetime
        self.now = now
    }

    func cached(_ category: HackerNews.API.Stories) -> FeedPage? { feeds[category] }

    func feed(_ category: HackerNews.API.Stories, forceRefresh: Bool = false) async throws
        -> FeedPage
    {
        try Task.checkCancellation()
        if !forceRefresh, let cached = feeds[category],
            now().timeIntervalSince(cached.fetchedAt) < lifetime
        {
            return cached
        }

        let generation = UUID()
        generations[category] = generation
        let response = try await service.storyIDs(for: category, forceRefresh: forceRefresh)
        var seen: Set<Int> = []
        let ids = response.filter { seen.insert($0).inserted }
        let batch = Array(ids.prefix(30))
        let items = try await service.items(ids: batch, forceRefresh: forceRefresh)
        try Task.checkCancellation()
        let page = FeedPage(
            ids: ids, items: items, nextOffset: batch.count,
            fetchedAt: now(), generation: generation)
        if generations[category] == generation { feeds[category] = page }
        return page
    }

    func nextPage(after page: FeedPage, category: HackerNews.API.Stories) async throws -> FeedPage {
        try Task.checkCancellation()
        guard page.hasMore else { return page }
        let batch = Array(page.ids.dropFirst(page.nextOffset).prefix(30))
        let items = try await service.items(ids: batch)
        try Task.checkCancellation()
        let result = FeedPage(
            ids: page.ids, items: page.items + items,
            nextOffset: page.nextOffset + batch.count,
            fetchedAt: page.fetchedAt, generation: page.generation)
        if feeds[category]?.generation == page.generation,
            (feeds[category]?.nextOffset ?? 0) <= result.nextOffset
        {
            feeds[category] = result
        }
        return result
    }
}
