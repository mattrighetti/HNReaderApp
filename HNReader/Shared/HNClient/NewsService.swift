import Foundation

struct NewsService: Sendable {
    static let shared = NewsService()

    private let session: URLSession
    private let cache: ItemCache

    init(
        session: URLSession = .shared,
        cacheLifetime: TimeInterval = 120,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.session = session
        cache = ItemCache(lifetime: cacheLifetime, now: now)
    }

    private func fetch<T: Decodable>(url: String, forceRefresh: Bool = false) async throws -> T {
        guard let url = URL(string: url) else {
            throw URLError(.badURL)
        }

        let request = URLRequest(
            url: url,
            cachePolicy: forceRefresh ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy,
            timeoutInterval: 20
        )

        let (data, response) = try await session.data(for: request)

        guard
            let response = response as? HTTPURLResponse,
            (200 ..< 300).contains(response.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    func storyIDs(
        for category: HackerNews.API.Stories,
        forceRefresh: Bool = false
    ) async throws -> [Int] {
        try await fetch(url: category.urlString, forceRefresh: forceRefresh)
    }

    func cachedItem(id: Int) -> Item? {
        cache.item(id: id)
    }

    func item(id: Int, forceRefresh: Bool = false) async throws -> Item? {
        try Task.checkCancellation()

        if !forceRefresh, let item = cache.item(id: id) {
            return item
        }

        let request = cache.beginRequest(id: id)

        defer {
            cache.cancelRequest(id: id, request: request)
        }

        let item: Item? = try await fetch(
            url: HackerNews.API.Item.id(id).urlString,
            forceRefresh: forceRefresh
        )
        try Task.checkCancellation()

        cache.finishRequest(id: id, request: request, item: item)

        return item
    }

    /// Fetch a whole page with at most eight requests in flight, preserving HN order.
    /// Callers receive one result only after every item has finished.
    func items(
        ids: [Int],
        forceRefresh: Bool = false
    ) async throws -> [Item] {
        try await withThrowingTaskGroup(of: (Int, Item?).self) { group in
            var nextIndex = 0
            var received: [Int: Item] = [:]

            for index in 0 ..< min(8, ids.count) {
                group.addTask {
                    (index, try await item(id: ids[index], forceRefresh: forceRefresh))
                }

                nextIndex += 1
            }

            while let (index, item) = try await group.next() {
                try Task.checkCancellation()
                if let item {
                    received[index] = item
                }

                // Refill before notifying the UI to keep networking moving.
                if nextIndex < ids.count {
                    let next = nextIndex
                    group.addTask {
                        (
                            next,
                            try await self.item(id: ids[next], forceRefresh: forceRefresh)
                        )
                    }

                    nextIndex += 1
                }

            }

            return received.keys.sorted().compactMap { received[$0] }
        }
    }
}
