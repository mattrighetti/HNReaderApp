import Foundation
import Observation

@MainActor
@Observable
final class CommentRepliesModel {
    private(set) var replies: [Item]
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var hasLoaded: Bool

    private let ids: [Int]
    private let service: NewsService
    private var nextOffset: Int

    var hasMore: Bool {
        nextOffset < ids.count
    }

    init(item: Item, service: NewsService = .shared, previewReplies: [Item]? = nil) {
        ids = item.kids ?? []
        self.service = service
        replies = previewReplies ?? []
        hasLoaded = previewReplies != nil
        nextOffset = previewReplies == nil ? 0 : ids.count
    }

    func loadNextPage() async {
        guard !isLoading, hasMore, !Task.isCancelled else {
            return
        }

        let page = Array(ids.dropFirst(nextOffset).prefix(15))
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let result = try await service.items(ids: page)
            try Task.checkCancellation()

            replies += result
            nextOffset += page.count
            hasLoaded = true
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }
}
