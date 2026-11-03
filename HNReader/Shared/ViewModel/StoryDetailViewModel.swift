import Foundation
import Observation

@MainActor
@Observable
final class StoryDetailViewModel {
    private(set) var item: Item
    private(set) var comments: [Item]
    private(set) var isLoading: Bool
    private(set) var errorMessage: String?

    private let service: NewsService
    private var hasLoadedMetadata: Bool
    private var loadedCount: Int

    var hasMoreComments: Bool {
        loadedCount < (item.kids?.count ?? 0)
    }

    init(
        item: Item,
        service: NewsService = .shared,
        initialComments: [Item]? = nil,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.item = item
        self.service = service
        comments = (initialComments ?? []).filter(\.isVisibleComment)
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        hasLoadedMetadata = initialComments != nil
        loadedCount = initialComments == nil ? 0 : item.kids?.count ?? 0
    }

    func loadComments() async {
        guard !isLoading, !Task.isCancelled else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            if !hasLoadedMetadata {
                guard let currentItem = try await service.item(id: item.id) else {
                    throw URLError(.resourceUnavailable)
                }

                try Task.checkCancellation()

                item = currentItem
                hasLoadedMetadata = true
            }

            var visibleComments: [Item] = []

            repeat {
                let ids = Array((item.kids ?? []).dropFirst(loadedCount).prefix(20))
                guard !ids.isEmpty else { break }

                let result = try await service.items(ids: ids)
                try Task.checkCancellation()

                visibleComments += result.filter(\.isVisibleComment)
                loadedCount += ids.count
            } while visibleComments.isEmpty && hasMoreComments

            comments += visibleComments
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }
}
