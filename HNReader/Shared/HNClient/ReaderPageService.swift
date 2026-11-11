import Foundation
import OSLog

/// Debug-only diagnostics: public item IDs and loading state, never comment text or account data.
enum DiscussionDiagnostics {
    private static let logger = Logger(
        subsystem: "com.mattrighetti.HNReader", category: "Comments")

    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
            let rendered = message()
            logger.notice("[HNComments] \(rendered, privacy: .public)")
        #endif
    }

    static func summary(_ item: Item?) -> String {
        guard let item else { return "item=null" }
        return "item=\(item.id) type=\(item.type?.rawValue ?? "nil") descendants=\(item.descendants ?? -1) kids=\(item.kids?.count ?? 0) firstKids=\(Array((item.kids ?? []).prefix(20))) deleted=\(item.deleted == true) dead=\(item.dead == true)"
    }
}

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
        ids: [Int], offset: Int, pageSize: Int = 20, requestID: UUID = UUID()
    ) async throws -> CommentPage {
        var cursor = offset
        var comments: [Item] = []
        repeat {
            let batch = Array(ids.dropFirst(cursor).prefix(pageSize))
            guard !batch.isEmpty else { break }
            DiscussionDiagnostics.log("batch.start request=\(requestID) offset=\(cursor) ids=\(batch)")
            let items = try await items(ids: batch)
            try Task.checkCancellation()
            let visible = items.filter(\.isVisibleComment)
            let returnedIDs = Set(items.map(\.id))
            DiscussionDiagnostics.log("batch.result request=\(requestID) visible=\(visible.map(\.id)) filtered=\(items.filter { !$0.isVisibleComment }.map(\.id)) missing=\(batch.filter { !returnedIDs.contains($0) })")
            comments += visible
            cursor += batch.count
        } while comments.isEmpty && cursor < ids.count
        return CommentPage(comments: comments, nextOffset: cursor)
    }

    func discussionPage(
        item snapshot: Item, offset: Int, fetchMetadata: Bool, requestID: UUID = UUID()
    ) async throws -> DiscussionPage
    {
        DiscussionDiagnostics.log("discussion.start request=\(requestID) offset=\(offset) fetchMetadata=\(fetchMetadata) \(DiscussionDiagnostics.summary(snapshot))")
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
        DiscussionDiagnostics.log("discussion.metadata request=\(requestID) \(DiscussionDiagnostics.summary(current))")
        let page = try await commentPage(
            ids: current.kids ?? [], offset: offset, requestID: requestID)
        try Task.checkCancellation()
        DiscussionDiagnostics.log("discussion.result request=\(requestID) story=\(current.id) comments=\(page.comments.map(\.id)) nextOffset=\(page.nextOffset)")
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
