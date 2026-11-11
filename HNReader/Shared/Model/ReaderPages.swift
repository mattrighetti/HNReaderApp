import Foundation

struct StoryRow: Identifiable {
    let rank: Int
    let item: Item
    var id: Int { item.id }

    static func savedRows(for items: [Item]) -> [StoryRow] {
        var rank = 0
        return items.map { item in
            if item.type != .comment { rank += 1 }
            return StoryRow(rank: item.type == .comment ? 0 : rank, item: item)
        }
    }
}

/// A complete feed snapshot. It contains domain data, never UI loading/error state.
struct FeedPage: Sendable {
    let ids: [Int]
    let items: [Item]
    let nextOffset: Int
    let fetchedAt: Date
    let generation: UUID

    init(
        ids: [Int] = [], items: [Item] = [], nextOffset: Int = 0,
        fetchedAt: Date = .distantPast, generation: UUID = UUID()
    ) {
        self.ids = ids
        self.items = items
        self.nextOffset = nextOffset
        self.fetchedAt = fetchedAt
        self.generation = generation
    }

    var hasMore: Bool { nextOffset < ids.count }

    var rows: [StoryRow] {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        return ids.prefix(nextOffset).enumerated().compactMap { index, id in
            guard let item = byID[id], item.deleted != true, item.dead != true else { return nil }
            return StoryRow(rank: index + 1, item: item)
        }
    }

    static func preview(_ rows: [StoryRow]) -> FeedPage {
        FeedPage(ids: rows.map(\.id), items: rows.map(\.item), nextOffset: rows.count)
    }
}

struct CommentPage: Sendable {
    let comments: [Item]
    let nextOffset: Int
}

struct DiscussionPage: Sendable {
    let item: Item
    let page: CommentPage
}

struct UserCommentPage: Sendable {
    let submitted: [Int]
    let page: CommentPage
}

struct StorySearchPage: Decodable, Sendable {
    private let hits: [Hit]
    private let page: Int
    private let nbPages: Int

    var items: [Item] { hits.compactMap(\.item) }

    var nextPage: Int? {
        guard page >= 0, nbPages > 0, page < nbPages - 1 else { return nil }
        return page + 1
    }

    private struct Hit: Decodable, Sendable {
        let objectID: String
        let title: String?
        let url: String?
        let author: String?
        let points: Int?
        let createdAt: Int?
        let storyText: String?
        let commentCount: Int?

        private enum CodingKeys: String, CodingKey {
            case objectID, title, url, author, points
            case createdAt = "created_at_i"
            case storyText = "story_text"
            case commentCount = "num_comments"
        }

        var item: Item? {
            guard let id = Int(objectID), id > 0 else { return nil }
            return Item(
                id: id, deleted: nil, type: .story, by: author, time: createdAt,
                text: storyText, dead: nil, parent: nil, poll: nil, kids: nil,
                url: url, score: points, title: title, parts: nil, descendants: commentCount
            )
        }
    }
}
