import SwiftUI

/// Owns one feed. SwiftUI tasks cancel old requests when the category changes.
@MainActor
final class ItemListViewModel: ObservableObject {
    @Published private(set) var stories: [Item] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasMore = false
    private var storyIDs: [Int] = []
    private var loadedCount = 0
    private var generation = UUID()

    func load(_ category: HackerNews.API.Stories) async {
        let request = UUID()
        generation = request
        isLoading = true
        errorMessage = nil
        stories = []
        storyIDs = []
        loadedCount = 0
        hasMore = false
        defer { if generation == request { isLoading = false } }
        do {
            let ids: [Int] = try await NewsService.fetch(url: category.urlString)
            let items = try await NewsService.items(ids: Array(ids.prefix(30)))
            try Task.checkCancellation()
            guard generation == request else { return }
            storyIDs = ids
            loadedCount = min(30, ids.count)
            stories = items.filter { $0.deleted != true && $0.dead != true }
            hasMore = loadedCount < ids.count
        } catch {
            guard generation == request, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        let request = generation
        isLoading = true
        errorMessage = nil
        defer { if generation == request { isLoading = false } }
        do {
            let ids = Array(storyIDs.dropFirst(loadedCount).prefix(30))
            let items = try await NewsService.items(ids: ids)
            try Task.checkCancellation()
            guard generation == request else { return }
            loadedCount += ids.count
            stories += items.filter { $0.deleted != true && $0.dead != true }
            hasMore = loadedCount < storyIDs.count
        } catch {
            guard generation == request, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}

enum NewsService {
    static func fetch<T: Decodable>(url: String) async throws -> T {
        guard let url = URL(string: url) else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Fetch in small batches and preserve HN's ranking, independent of response order.
    static func items(ids: [Int]) async throws -> [Item] {
        var result: [Item] = []
        for start in stride(from: 0, to: ids.count, by: 8) {
            try Task.checkCancellation()
            let batch = Array(ids[start..<min(start + 8, ids.count)])
            let items = try await withThrowingTaskGroup(of: (Int, Item?).self) { group in
                for (index, id) in batch.enumerated() {
                    group.addTask {
                        let item: Item? = try await fetch(url: HackerNews.API.Item.id(id).urlString)
                        return (index, item)
                    }
                }
                var values: [(Int, Item?)] = []
                for try await value in group { values.append(value) }
                return values.sorted { $0.0 < $1.0 }.compactMap(\.1)
            }
            result += items
        }
        return result
    }
}
