import Foundation
import Combine

@MainActor
final class StoryDetailViewModel: ObservableObject {
    @Published private(set) var item: Item
    @Published private(set) var comments: [Item]
    @Published private(set) var isLoading: Bool
    @Published private(set) var errorMessage: String?

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
        comments = initialComments ?? []
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

            let ids = Array((item.kids ?? []).dropFirst(loadedCount).prefix(20))
            let result = try await service.items(ids: ids)
            try Task.checkCancellation()

            comments += result
            loadedCount += ids.count
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }
}
