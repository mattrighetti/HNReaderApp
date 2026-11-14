import Foundation

extension NewsService {
    /// Resolve a comment's parent chain to the story, poll, or job that owns the discussion.
    func storyContext(for comment: Item) async throws -> Item {
        var current = comment
        var visited = Set([comment.id])

        while current.type == .comment {
            try Task.checkCancellation()
            guard let parentID = current.parent, visited.insert(parentID).inserted else {
                throw URLError(.resourceUnavailable)
            }
            guard let parent = try await item(id: parentID) else {
                throw URLError(.resourceUnavailable)
            }
            current = parent
        }

        guard current.deleted != true, current.dead != true else {
            throw URLError(.resourceUnavailable)
        }
        return current
    }

    /// Return one atomic page, skipping batches that contain no visible comments.
    func commentPage(
        ids: [Int], offset: Int, pageSize: Int = 20
    ) async throws -> CommentPage {
        var cursor = offset
        var comments: [Item] = []
        repeat {
            let batch = Array(ids.dropFirst(cursor).prefix(pageSize))
            guard !batch.isEmpty else { break }
            let items = try await items(ids: batch)
            try Task.checkCancellation()
            let visible = items.filter(\.isVisibleComment)
            comments += visible
            cursor += batch.count
        } while comments.isEmpty && cursor < ids.count
        return CommentPage(comments: comments, nextOffset: cursor)
    }

    func discussionPage(
        item snapshot: Item, offset: Int, fetchMetadata: Bool
    ) async throws -> DiscussionPage
    {
        let current: Item
        if fetchMetadata {
            // Feed and saved snapshots may predate the story's latest comment IDs.
            guard let fresh = try await item(id: snapshot.id, forceRefresh: true) else {
                throw URLError(.resourceUnavailable)
            }
            current = fresh
        } else {
            current = snapshot
        }
        let page = try await commentPage(
            ids: current.kids ?? [], offset: offset)
        try Task.checkCancellation()
        return DiscussionPage(item: current, page: page)
    }

    /// Cursor and comments are returned together; no partial progress escapes on failure.
    func userCommentPage(
        username: String, submitted: [Int], offset: Int,
        forceRefresh: Bool = false
    ) async throws -> UserCommentPage {
        let ids: [Int]
        if forceRefresh {
            guard let current = try await user(id: username, forceRefresh: true) else {
                throw URLError(.resourceUnavailable)
            }
            ids = current.submitted ?? []
        } else {
            ids = submitted
        }
        var cursor = forceRefresh ? 0 : offset
        var comments: [Item] = []
        var scanned = 0
        repeat {
            let batch = Array(ids.dropFirst(cursor).prefix(20))
            guard !batch.isEmpty else { break }
            let items = try await items(ids: batch, forceRefresh: forceRefresh)
            try Task.checkCancellation()
            comments += items.filter {
                $0.type == .comment && $0.isVisibleComment && $0.by == username
            }
            cursor += batch.count
            scanned += batch.count
        } while comments.count < 15 && cursor < ids.count && scanned < 80
        return UserCommentPage(
            submitted: ids, page: CommentPage(comments: comments, nextOffset: cursor))
    }
}
