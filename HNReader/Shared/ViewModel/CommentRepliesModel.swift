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

    var visibleReplyCountEstimate: Int {
        replies.count + (ids.count - nextOffset)
    }

    init(item: Item, service: NewsService = .shared, previewReplies: [Item]? = nil) {
        ids = item.kids ?? []
        self.service = service
        replies = (previewReplies ?? []).filter(\.isVisibleComment)
        hasLoaded = previewReplies != nil
        nextOffset = previewReplies == nil ? 0 : ids.count
    }

    func loadNextPage() async {
        guard !isLoading, hasMore, !Task.isCancelled else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            var visibleReplies: [Item] = []

            repeat {
                let page = Array(ids.dropFirst(nextOffset).prefix(15))
                guard !page.isEmpty else { break }

                let result = try await service.items(ids: page)
                try Task.checkCancellation()

                visibleReplies += result.filter(\.isVisibleComment)
                nextOffset += page.count
            } while visibleReplies.isEmpty && hasMore

            replies += visibleReplies
            hasLoaded = true
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }
}
