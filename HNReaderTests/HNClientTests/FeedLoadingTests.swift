import SwiftUI
import XCTest

@testable import HNReader

final class FeedLoadingTests: XCTestCase {
    func testStorySearchMapsHitsAndPaginatesWithoutFetchingFirebaseItems() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        server.respond("/api/v1/search", json: """
            {
                "page": 1,
                "nbPages": 3,
                "hits": [
                    {
                        "objectID": "42",
                        "title": "An article",
                        "url": "https://example.com",
                        "author": "alice",
                        "created_at_i": 1234,
                        "points": 9,
                        "num_comments": 2
                    },
                    {
                        "objectID": "43",
                        "title": "Ask HN: A question",
                        "url": null,
                        "story_text": "A text post"
                    },
                    { "objectID": "invalid" }
                ]
            }
            """)
        server.respond("/api/v1/search_by_date", json: #"{"page":0,"nbPages":1,"hits":[]}"#)
        let service = NewsService(session: server.session)

        let page = try await service.searchStories(query: "question", sort: .relevance, page: 1)
        let items = page.items
        let article = try XCTUnwrap(items.first)
        let textPost = try XCTUnwrap(items.last)
        XCTAssertEqual(items.map(\.id), [42, 43])
        XCTAssertEqual(article.type, .story)
        XCTAssertEqual(article.title, "An article")
        XCTAssertEqual(article.articleURL?.host, "example.com")
        XCTAssertEqual(article.by, "alice")
        XCTAssertEqual(article.time, 1234)
        XCTAssertEqual(article.score, 9)
        XCTAssertEqual(article.descendants, 2)
        XCTAssertNil(textPost.articleURL)
        XCTAssertEqual(textPost.text, "A text post")
        XCTAssertEqual(page.nextPage, 2)
        XCTAssertEqual(server.totalRequests, 1)

        let lastPage = try await service.searchStories(query: "question", sort: .newest, page: 0)
        XCTAssertTrue(lastPage.items.isEmpty)
        XCTAssertNil(lastPage.nextPage)
    }

    func testPoolIsBoundedAndRefillsBeforeSlowRequestFinishes() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        let firstEight = expectation(description: "Eight requests started")
        firstEight.expectedFulfillmentCount = 8

        let ninth = expectation(description: "Next slot refills independently")
        let initialPaths = Set((1...8).map { "/v0/item/\($0).json" })

        server.hold(initialPaths)
        server.observe { path in
            if initialPaths.contains(path) {
                firstEight.fulfill()
            }

            if path == "/v0/item/9.json" {
                ninth.fulfill()
            }
        }

        let service = NewsService(session: server.session)
        let task = Task {
            try await service.items(ids: Array(1...12))
        }

        await fulfillment(of: [firstEight], timeout: 3)
        XCTAssertEqual(server.totalRequests, 8)

        server.release("/v0/item/8.json")
        await fulfillment(of: [ninth], timeout: 3)

        server.releaseAll()
        let result = try await task.value

        XCTAssertEqual(result.map(\.id), Array(1...12))
        XCTAssertEqual(server.totalRequests, 12)
    }

    func testItemCacheIsSharedAndRefreshBypassesIt() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        let service = NewsService(session: server.session)
        _ = try await service.items(ids: [1, 2])
        _ = try await service.items(ids: [2, 3])

        XCTAssertEqual(server.count("/v0/item/2.json"), 1)

        _ = try await service.items(ids: [2], forceRefresh: true)

        XCTAssertEqual(server.count("/v0/item/2.json"), 2)
    }

    func testCommentContextWalksParentsToRootStory() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        server.respond(
            "/v0/item/100.json",
            json: #"{"id":100,"type":"comment","parent":42,"text":"Parent"}"#
        )
        server.respond(
            "/v0/item/42.json",
            json: #"{"id":42,"type":"story","title":"Root story","url":"https://example.com"}"#
        )
        let comment = try decode(
            #"{"id":101,"type":"comment","parent":100,"text":"Upvoted"}"#
        )

        let story = try await NewsService(session: server.session).storyContext(for: comment)

        XCTAssertEqual(story.id, 42)
        XCTAssertEqual(story.title, "Root story")
        XCTAssertEqual(server.count("/v0/item/100.json"), 1)
        XCTAssertEqual(server.count("/v0/item/42.json"), 1)
    }

    func testCommentContextRejectsParentCycle() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        server.respond(
            "/v0/item/100.json",
            json: #"{"id":100,"type":"comment","parent":101,"text":"Parent"}"#
        )
        let comment = try decode(
            #"{"id":101,"type":"comment","parent":100,"text":"Upvoted"}"#
        )

        do {
            _ = try await NewsService(session: server.session).storyContext(for: comment)
            XCTFail("Expected a cyclic parent chain to fail")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .resourceUnavailable)
        }

        XCTAssertEqual(server.totalRequests, 1)
    }

    func testExpiredItemsAreFetchedAgain() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        let clock = FeedTestClock()
        let service = NewsService(session: server.session, cacheLifetime: 120, now: { clock.now })
        _ = try await service.items(ids: [1])

        clock.advance(121)
        _ = try await service.items(ids: [1])

        XCTAssertEqual(server.count("/v0/item/1.json"), 2)
    }

    func testOlderRequestCannotOverwriteARefreshedItem() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        let path = "/v0/item/42.json"
        let started = expectation(description: "Original request started")
        server.hold([path])
        server.observe { _ in started.fulfill() }

        let service = NewsService(session: server.session)
        let original = Task { try await service.item(id: 42) }
        await fulfillment(of: [started], timeout: 3)

        server.observe { _ in }
        server.unhold(path)
        server.respond(path, json: #"{"id":42,"title":"Fresh"}"#)

        let refreshed = try await service.item(id: 42, forceRefresh: true)
        server.release(path, json: #"{"id":42,"title":"Old"}"#)
        let older = try await original.value
        let cached = try await service.item(id: 42)

        XCTAssertEqual(refreshed?.title, "Fresh")
        XCTAssertEqual(older?.title, "Old")
        XCTAssertEqual(cached?.title, "Fresh")
        XCTAssertEqual(server.count(path), 2)
    }

    func testFailedRefreshDoesNotAllowAnOlderRequestToPopulateTheCache() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        let path = "/v0/item/42.json"
        let started = expectation(description: "Original request started")
        server.hold([path])
        server.observe { _ in started.fulfill() }

        let service = NewsService(session: server.session)
        let original = Task { try await service.item(id: 42) }
        await fulfillment(of: [started], timeout: 3)

        server.observe { _ in }
        server.unhold(path)
        server.respond(path, json: "{}", status: 500)

        do {
            _ = try await service.item(id: 42, forceRefresh: true)
            XCTFail("Refresh should fail")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }

        server.release(path, json: #"{"id":42,"title":"Old"}"#)
        _ = try await original.value

        XCTAssertNil(service.cachedItem(id: 42))
    }

    func testDiscussionOpeningRefreshesCachedStoryCommentIDs() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        let path = "/v0/item/42.json"
        server.respond(path, json: #"{"id":42,"type":"story","descendants":0}"#)
        let service = NewsService(session: server.session)
        let cached = try await service.item(id: 42)
        let snapshot = try XCTUnwrap(cached)
        server.respond(
            path, json: #"{"id":42,"type":"story","kids":[101],"descendants":1}"#)

        let result = try await service.discussionPage(
            item: snapshot, offset: 0, fetchMetadata: true)

        XCTAssertEqual(result.item.descendants, 1)
        XCTAssertEqual(result.page.comments.map(\.id), [101])
        XCTAssertEqual(server.count(path), 2)

        server.respond(
            path, json: #"{"id":42,"type":"story","kids":[102,101],"descendants":2}"#)
        let reopened = try await service.discussionPage(
            item: snapshot, offset: 0, fetchMetadata: true)
        XCTAssertEqual(reopened.page.comments.map(\.id), [102, 101])
        XCTAssertEqual(server.count(path), 3)
        XCTAssertEqual(server.count("/v0/item/101.json"), 1)
    }

    func testSavedStoryFetchesCurrentMetadataBeforeLoadingComments() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        let saved = try decode(#"{"id":42,"title":"Saved snapshot"}"#)
        server.respond(
            "/v0/item/42.json",
            json: #"{"id":42,"title":"Current title","kids":[101,102],"descendants":2}"#)
        let service = NewsService(session: server.session)
        let result = try await service.discussionPage(item: saved, offset: 0, fetchMetadata: true)
        XCTAssertEqual(result.item.title, "Current title")
        XCTAssertEqual(result.item.descendants, 2)
        XCTAssertEqual(result.page.comments.map(\.id), [101, 102])
        XCTAssertEqual(saved.title, "Saved snapshot")
        _ = try await service.discussionPage(item: saved, offset: 0, fetchMetadata: true)
        XCTAssertEqual(server.count("/v0/item/42.json"), 2)
        XCTAssertEqual(server.count("/v0/item/101.json"), 1)
    }

    func testFailedStoryMetadataKeepsSavedContentAndCanBeRetried() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        let saved = try decode(#"{"id":42,"title":"Saved snapshot","kids":[1]}"#)
        let service = NewsService(session: server.session)
        server.respond("/v0/item/42.json", json: "{}", status: 500)
        do {
            _ = try await service.discussionPage(item: saved, offset: 0, fetchMetadata: true)
            XCTFail("Metadata failure must not produce a partial page")
        } catch {}
        XCTAssertEqual(saved.title, "Saved snapshot")
        XCTAssertEqual(server.count("/v0/item/1.json"), 0)
        server.respond("/v0/item/42.json", json: #"{"id":42,"kids":[2]}"#)
        let result = try await service.discussionPage(item: saved, offset: 0, fetchMetadata: true)
        XCTAssertEqual(result.page.comments.map(\.id), [2])
    }

    func testFailedCommentPageRetainsItsOffsetAndMetadata() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        let service = NewsService(session: server.session)
        let item = try decode(
            "{\"id\":42,\"kids\":[\((1...25).map(String.init).joined(separator: ","))]}")
        let first = try await service.discussionPage(item: item, offset: 0, fetchMetadata: false)
        server.respond("/v0/item/25.json", json: "{}", status: 500)
        do {
            _ = try await service.discussionPage(
                item: item, offset: first.page.nextOffset, fetchMetadata: false)
            XCTFail("Page must fail atomically")
        } catch {}
        XCTAssertEqual(first.page.comments.map(\.id), Array(1...20))
        XCTAssertEqual(first.page.nextOffset, 20)
        server.respond("/v0/item/25.json", json: #"{"id":25}"#)
        let second = try await service.discussionPage(
            item: item, offset: first.page.nextOffset, fetchMetadata: false)
        XCTAssertEqual(second.page.comments.map(\.id), Array(21...25))
        XCTAssertEqual(second.page.nextOffset, 25)
    }

    func testPagesAppearAtomicallyInGroupsOfThirty() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        server.respond(
            "/v0/topstories.json", json: "[\((1...65).map(String.init).joined(separator: ","))]")
        server.hold(["/v0/item/30.json", "/v0/item/60.json"])
        let firstReady = expectation(description: "First page waits")
        let secondReady = expectation(description: "Second page waits")
        server.observe { path in
            if path == "/v0/item/30.json" { firstReady.fulfill() }
            if path == "/v0/item/60.json" { secondReady.fulfill() }
        }
        let repository = FeedRepository(service: NewsService(session: server.session))
        let firstTask = Task { try await repository.feed(.top) }
        await fulfillment(of: [firstReady], timeout: 3)
        let pending = await repository.cached(.top)
        XCTAssertNil(pending)
        XCTAssertEqual(server.count("/v0/item/31.json"), 0)
        server.release("/v0/item/30.json")
        let first = try await firstTask.value
        XCTAssertEqual(first.rows.map(\.id), Array(1...30))
        let secondTask = Task { try await repository.nextPage(after: first, category: .top) }
        await fulfillment(of: [secondReady], timeout: 3)
        let cached = await repository.cached(.top)
        XCTAssertEqual(cached?.rows.map(\.id), Array(1...30))
        XCTAssertEqual(server.count("/v0/item/61.json"), 0)
        server.release("/v0/item/60.json")
        let second = try await secondTask.value
        let third = try await repository.nextPage(after: second, category: .top)
        XCTAssertEqual(third.rows.map(\.id), Array(1...65))
        XCTAssertEqual(third.rows.map(\.rank), Array(1...65))
        XCTAssertFalse(third.hasMore)
    }

    func testSectionCacheRestoresAllLoadedPagesAndOffset() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        server.respond("/v0/beststories.json", json: "[1]")
        let repository = FeedRepository(service: NewsService(session: server.session))
        let first = try await repository.feed(.top)
        _ = try await repository.nextPage(after: first, category: .top)
        _ = try await repository.feed(.best)
        let requests = server.totalRequests
        let restored = try await repository.feed(.top)
        XCTAssertEqual(restored.rows.map(\.id), Array(1...40))
        XCTAssertFalse(restored.hasMore)
        XCTAssertEqual(server.totalRequests, requests)
        let refreshed = try await repository.feed(.top, forceRefresh: true)
        XCTAssertEqual(refreshed.rows.count, 30)
        XCTAssertEqual(server.count("/v0/topstories.json"), 2)
        XCTAssertEqual(server.count("/v0/item/1.json"), 2)
    }

    func testFailedPageKeepsExistingRowsAndCanBeRetried() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        let repository = FeedRepository(service: NewsService(session: server.session))
        let first = try await repository.feed(.top)
        server.respond("/v0/item/35.json", json: "{}", status: 500)
        do {
            _ = try await repository.nextPage(after: first, category: .top)
            XCTFail("Expected page failure")
        } catch {}
        let cached = await repository.cached(.top)
        XCTAssertEqual(cached?.rows.map(\.id), Array(1...30))
        XCTAssertTrue(first.hasMore)
        server.respond("/v0/item/35.json", json: #"{"id":35,"title":"Recovered"}"#)
        let retried = try await repository.nextPage(after: first, category: .top)
        XCTAssertEqual(retried.rows.map(\.id), Array(1...40))
        XCTAssertFalse(retried.hasMore)
    }

    func testMissingStoriesAdvanceByRequestedIDsAndPreserveRank() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        server.respond("/v0/item/2.json", json: "null")
        server.respond("/v0/item/3.json", json: #"{"id":3,"deleted":true}"#)
        let repository = FeedRepository(service: NewsService(session: server.session))
        let first = try await repository.feed(.top)
        let page = try await repository.nextPage(after: first, category: .top)
        XCTAssertEqual(page.rows.map(\.id), [1] + Array(4...40))
        XCTAssertEqual(page.rows.map(\.rank), [1] + Array(4...40))
        XCTAssertFalse(page.hasMore)
    }

    func testStaleSectionRemainsVisibleIfRefreshFails() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        let clock = FeedTestClock()
        let repository = FeedRepository(
            service: NewsService(session: server.session), now: { clock.now })
        let first = try await repository.feed(.top)
        clock.advance(61)
        server.respond("/v0/topstories.json", json: "{}", status: 500)
        do {
            _ = try await repository.feed(.top)
            XCTFail("Expected refresh failure")
        } catch {}
        let cached = await repository.cached(.top)
        XCTAssertEqual(cached?.rows.map(\.id), first.rows.map(\.id))
    }

    func testLatePageCannotOverwriteAnotherSection() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        server.respond("/v0/beststories.json", json: "[101]")
        server.hold(["/v0/item/31.json"])
        let started = expectation(description: "Old page started")
        server.observe { if $0 == "/v0/item/31.json" { started.fulfill() } }
        let repository = FeedRepository(service: NewsService(session: server.session))
        let first = try await repository.feed(.top)
        let old = Task { try await repository.nextPage(after: first, category: .top) }
        await fulfillment(of: [started], timeout: 3)
        let best = try await repository.feed(.best)
        server.releaseAll()
        _ = try await old.value
        let cachedBest = await repository.cached(.best)
        XCTAssertEqual(best.rows.map(\.id), [101])
        XCTAssertEqual(cachedBest?.rows.map(\.id), [101])
    }

    func testLatePageCannotReplaceARefreshedFeed() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        let repository = FeedRepository(service: NewsService(session: server.session))
        let first = try await repository.feed(.top)
        let started = expectation(description: "Old page started")
        server.hold(["/v0/item/31.json"])
        server.observe { if $0 == "/v0/item/31.json" { started.fulfill() } }
        let old = Task { try await repository.nextPage(after: first, category: .top) }
        await fulfillment(of: [started], timeout: 3)
        server.respond("/v0/topstories.json", json: "[101]")
        let refreshed = try await repository.feed(.top, forceRefresh: true)
        server.releaseAll()
        _ = try await old.value
        let cached = await repository.cached(.top)
        XCTAssertEqual(cached?.generation, refreshed.generation)
        XCTAssertEqual(cached?.rows.map(\.id), [101])
    }

    func testEmptyFeedDoesNotRequestItemsOrFurtherPages() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        server.respond("/v0/topstories.json", json: "[]")
        let repository = FeedRepository(service: NewsService(session: server.session))
        let first = try await repository.feed(.top)
        let last = try await repository.nextPage(after: first, category: .top)
        XCTAssertTrue(last.rows.isEmpty)
        XCTAssertFalse(last.hasMore)
        XCTAssertEqual(server.totalRequests, 1)
    }

    func testRepliesLoadOnDemandInPagesAndReuseTheItemCache() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        let service = NewsService(session: server.session)
        let ids = Array(1...31)
        XCTAssertEqual(server.totalRequests, 0)
        let first = try await service.commentPage(ids: ids, offset: 0, pageSize: 15)
        XCTAssertEqual(first.comments.map(\.id), Array(1...15))
        XCTAssertEqual(server.count("/v0/item/16.json"), 0)
        let second = try await service.commentPage(ids: ids, offset: first.nextOffset, pageSize: 15)
        let third = try await service.commentPage(ids: ids, offset: second.nextOffset, pageSize: 15)
        XCTAssertEqual(third.comments.map(\.id), [31])
        _ = try await service.commentPage(ids: ids, offset: 0, pageSize: 15)
        XCTAssertEqual(server.totalRequests, 31)
    }

    func testFailedRepliesCanBeRetriedWithoutAdvancingThePage() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        let service = NewsService(session: server.session)
        server.respond("/v0/item/2.json", json: "{}", status: 500)
        do {
            _ = try await service.commentPage(ids: [1, 2], offset: 0, pageSize: 15)
            XCTFail("Expected failure")
        } catch {}
        server.respond("/v0/item/2.json", json: #"{"id":2}"#)
        let page = try await service.commentPage(ids: [1, 2], offset: 0, pageSize: 15)
        XCTAssertEqual(page.comments.map(\.id), [1, 2])
        XCTAssertEqual(page.nextOffset, 2)
    }

    func testCancelledRepliesDoNotAdvanceAndCanBeReopened() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        let service = NewsService(session: server.session)
        let started = expectation(description: "Reply started")
        server.hold(["/v0/item/1.json"])
        server.observe { _ in started.fulfill() }
        let task = Task { try await service.commentPage(ids: [1], offset: 0, pageSize: 15) }
        await fulfillment(of: [started], timeout: 3)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {}
        server.observe { _ in }
        server.releaseAll()
        let page = try await service.commentPage(ids: [1], offset: 0, pageSize: 15)
        XCTAssertEqual(page.comments.map(\.id), [1])
        XCTAssertEqual(page.nextOffset, 1)
    }

    func testUserCommentsRetryIncludesCommentsFromTheEarlierSuccessfulBatch() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        for id in 1...40 {
            server.respond(
                "/v0/item/\(id).json",
                json:
                    "{\"id\":\(id),\"type\":\"\(id <= 5 ? "comment" : "story")\",\"by\":\"reader\"}"
            )
        }
        let service = NewsService(session: server.session)
        let ids = Array(1...40)
        server.respond("/v0/item/21.json", json: "{}", status: 500)
        do {
            _ = try await service.userCommentPage(username: "reader", submitted: ids, offset: 0)
            XCTFail("Expected failure after the first batch")
        } catch {}
        server.respond("/v0/item/21.json", json: #"{"id":21,"type":"story","by":"reader"}"#)
        let result = try await service.userCommentPage(
            username: "reader", submitted: ids, offset: 0)
        XCTAssertEqual(result.page.comments.map(\.id), Array(1...5))
        XCTAssertEqual(result.page.nextOffset, 40)
    }

    func testUserCommentsRefreshFetchesNewSubmissionIDs() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        server.respond(
            "/v0/user/reader.json",
            json: #"{"id":"reader","created":1,"karma":1,"submitted":[99,1]}"#)
        server.respond("/v0/item/99.json", json: #"{"id":99,"type":"comment","by":"reader"}"#)
        let result = try await NewsService(session: server.session).userCommentPage(
            username: "reader", submitted: [1], offset: 1, forceRefresh: true)
        XCTAssertEqual(result.submitted, [99, 1])
        XCTAssertEqual(result.page.comments.map(\.id), [99])
        XCTAssertEqual(result.page.nextOffset, 2)
        XCTAssertEqual(server.count("/v0/user/reader.json"), 1)
    }

    func testUserCommentsScanIsBoundedAndContinuesFromReturnedCursor() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        let result = try await NewsService(session: server.session).userCommentPage(
            username: "reader", submitted: Array(1...200), offset: 0)
        XCTAssertTrue(result.page.comments.isEmpty)
        XCTAssertEqual(result.page.nextOffset, 80)
        XCTAssertEqual(server.totalRequests, 80)
    }

    func testUserCommentsCancellationDoesNotLoseEarlierBatches() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        server.respond("/v0/item/1.json", json: #"{"id":1,"type":"comment","by":"reader"}"#)
        server.hold(["/v0/item/21.json"])
        let started = expectation(description: "Second batch started")
        server.observe { if $0 == "/v0/item/21.json" { started.fulfill() } }
        let service = NewsService(session: server.session)
        let task = Task {
            try await service.userCommentPage(
                username: "reader", submitted: Array(1...40), offset: 0)
        }
        await fulfillment(of: [started], timeout: 3)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {}
        server.observe { _ in }
        server.releaseAll()
        let result = try await service.userCommentPage(
            username: "reader", submitted: Array(1...40), offset: 0)
        XCTAssertEqual(result.page.comments.map(\.id), [1])
        XCTAssertEqual(result.page.nextOffset, 40)
    }

    func testCacheCanBeClearedAndPreservesLargeIDs() throws {
        let cache = ItemCache()
        let item = try decode(#"{"id":4294967297}"#)
        cache.insert(item)
        XCTAssertEqual(cache.item(id: item.id), item)
        XCTAssertNil(cache.item(id: 1))
        cache.removeAll()
        XCTAssertNil(cache.item(id: item.id))
    }

    @MainActor
    func testNativeListLoadsNextPageOnlyAtBottom() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        server.respond(
            "/v0/topstories.json", json: "[\((1...65).map(String.init).joined(separator: ","))]")
        let repository = FeedRepository(service: NewsService(session: server.session))
        _ = try await repository.feed(.top)
        let second = expectation(description: "Second page requested")
        let third = expectation(description: "Third page requested")
        server.observe { path in
            if path == "/v0/item/60.json" { second.fulfill() }
            if path == "/v0/item/65.json" { third.fulfill() }
        }
        let window = makeWindow(repository: repository)
        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(server.count("/v0/item/31.json"), 0)
        let scroll = try XCTUnwrap(Self.tableScrollView(in: try XCTUnwrap(window.contentView)))
        Self.scrollToBottom(scroll)
        await fulfillment(of: [second], timeout: 3)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(server.count("/v0/item/61.json"), 0)
        Self.scrollToBottom(scroll)
        await fulfillment(of: [third], timeout: 3)
        try await Task.sleep(for: .milliseconds(150))
        let cached = await repository.cached(.top)
        XCTAssertEqual(cached?.rows.count, 65)
        XCTAssertEqual(server.count("/v0/item/31.json"), 1)
    }

    @MainActor
    func testEmptyUnreadPageLoadsTheNextPage() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        let repository = FeedRepository(service: NewsService(session: server.session))
        let first = try await repository.feed(.top)
        let suite = "HNReaderTests.Unread.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(defaults: defaults)
        first.items.forEach { state.markRead($0) }
        let loaded = expectation(description: "Unread page requested")
        server.observe { if $0 == "/v0/item/40.json" { loaded.fulfill() } }
        let window = makeWindow(repository: repository, state: state, unreadOnly: true)
        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        await fulfillment(of: [loaded], timeout: 3)
        try await Task.sleep(for: .milliseconds(100))
        let cached = await repository.cached(.top)
        XCTAssertEqual(cached?.rows.filter { $0.id > 30 }.map(\.id), Array(31...40))
    }

    @MainActor
    func testEmptyUnreadPagesContinueUntilAnUnreadStoryIsFound() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        server.respond(
            "/v0/topstories.json", json: "[\((1...65).map(String.init).joined(separator: ","))]")
        let repository = FeedRepository(service: NewsService(session: server.session))
        _ = try await repository.feed(.top)
        let suite = "HNReaderTests.UnreadPages.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(defaults: defaults)
        for id in 1...60 {
            state.markRead(try decode("{\"id\":\(id)}"))
        }
        let loaded = expectation(description: "Unread third page requested")
        server.observe { if $0 == "/v0/item/65.json" { loaded.fulfill() } }
        let window = makeWindow(repository: repository, state: state, unreadOnly: true)
        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        await fulfillment(of: [loaded], timeout: 3)
        try await Task.sleep(for: .milliseconds(100))
        let cached = await repository.cached(.top)
        XCTAssertEqual(cached?.nextOffset, 65)
    }

    @MainActor
    func testVisibleFooterContinuesPastADeletedPage() async throws {
        let server = FeedTestServer()
        defer { server.close() }
        server.respond(
            "/v0/topstories.json", json: "[\((1...65).map(String.init).joined(separator: ","))]")
        for id in 31...60 {
            server.respond("/v0/item/\(id).json", json: "{\"id\":\(id),\"deleted\":true}")
        }
        let repository = FeedRepository(service: NewsService(session: server.session))
        _ = try await repository.feed(.top)
        let loaded = expectation(description: "Third page requested after deleted second page")
        server.observe { if $0 == "/v0/item/65.json" { loaded.fulfill() } }
        let window = makeWindow(repository: repository)
        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(200))
        let scroll = try XCTUnwrap(Self.tableScrollView(in: try XCTUnwrap(window.contentView)))
        Self.scrollToBottom(scroll)
        await fulfillment(of: [loaded], timeout: 3)
        try await Task.sleep(for: .milliseconds(100))
        let cached = await repository.cached(.top)
        XCTAssertEqual(cached?.rows.map(\.id), Array(1...30) + Array(61...65))
        XCTAssertEqual(cached?.nextOffset, 65)
    }

    @MainActor
    private func makeWindow(
        repository: FeedRepository, state: AppState? = nil, unreadOnly: Bool = false
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 650),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let defaults = UserDefaults(suiteName: "HNReaderTests.Window.\(UUID().uuidString)")!
        window.contentView = NSHostingView(
            rootView: HomeView(
                initialUnreadOnly: unreadOnly, repository: repository
            )
            .environment(state ?? AppState(defaults: defaults)))
        return window
    }

    private func decode(_ json: String) throws -> Item {
        try JSONDecoder().decode(Item.self, from: Data(json.utf8))
    }

    @MainActor
    private static func tableScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView,
            let table = scroll.documentView as? NSTableView, table.numberOfRows >= 30
        {
            return scroll
        }
        return view.subviews.lazy.compactMap { tableScrollView(in: $0) }.first
    }

    @MainActor
    private static func scrollToBottom(_ scroll: NSScrollView) {
        guard let document = scroll.documentView else { return }
        scroll.contentView.scroll(
            to: NSPoint(x: 0, y: document.bounds.height - scroll.contentSize.height))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
}

/// A controllable HTTP server inside URLSession; tests never contact Firebase.
private final class FeedTestServer: @unchecked Sendable {
    private let lock = NSLock()
    private let token = UUID().uuidString
    private var counts: [String: Int] = [:]
    private var heldPaths: Set<String> = []
    private var pending: [String: FeedTestProtocol] = [:]
    private var responses: [String: (String, Int)] = [:]
    private var observer: (@Sendable (String) -> Void)?
    let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.protocolClasses = [FeedTestProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Test-Session": token]
        session = URLSession(configuration: configuration)
        FeedTestProtocol.register(token) { [weak self] request in self?.start(request) }
    }

    func close() {
        session.invalidateAndCancel()
        FeedTestProtocol.unregister(token)
    }

    var totalRequests: Int {
        lock.withLock { counts.values.reduce(0, +) }
    }

    func count(_ path: String) -> Int {
        lock.withLock { counts[path, default: 0] }
    }

    func hold(_ paths: Set<String>) {
        lock.withLock { heldPaths = paths }
    }

    func unhold(_ path: String) {
        _ = lock.withLock { heldPaths.remove(path) }
    }

    func observe(_ callback: @escaping @Sendable (String) -> Void) {
        lock.withLock { observer = callback }
    }

    func respond(_ path: String, json: String, status: Int = 200) {
        lock.withLock { responses[path] = (json, status) }
    }

    private func start(_ request: FeedTestProtocol) {
        let path = request.request.url!.path
        let (held, callback) = lock.withLock {
            counts[path, default: 0] += 1
            let held = heldPaths.contains(path)
            if held {
                pending[path] = request
            }
            return (held, observer)
        }
        callback?(path)
        if !held {
            reply(request)
        }
    }

    func release(_ path: String, json: String? = nil) {
        let request = lock.withLock { pending.removeValue(forKey: path) }
        if let request {
            if let json {
                request.respond(json)
            } else {
                reply(request)
            }
        }
    }

    func releaseAll() {
        let requests = lock.withLock {
            heldPaths = []
            let requests = Array(pending.values)
            pending = [:]
            return requests
        }
        for request in requests {
            reply(request)
        }
    }

    private func reply(_ request: FeedTestProtocol) {
        let path = request.request.url!.path
        let response = lock.withLock { responses[path] }
        if let (json, status) = response {
            request.respond(json, status: status)
        } else if path.contains("/item/") {
            let id = request.request.url!.deletingPathExtension().lastPathComponent
            request.respond("{\"id\":\(id),\"title\":\"Story \(id)\"}")
        } else {
            request.respond("[\((1 ... 40).map(String.init).joined(separator: ","))]")
        }
    }
}

private final class FeedTestProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var handlers: [String: @Sendable (FeedTestProtocol) -> Void] = [:]
    private let stateLock = NSLock()
    private var stopped = false

    static func register(_ token: String, handler: @escaping @Sendable (FeedTestProtocol) -> Void) {
        lock.withLock { handlers[token] = handler }
    }

    static func unregister(_ token: String) {
        _ = lock.withLock { handlers.removeValue(forKey: token) }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let token = request.value(forHTTPHeaderField: "X-Test-Session") ?? ""
        let handler = Self.lock.withLock { Self.handlers[token] }
        handler?(self)
    }

    override func stopLoading() {
        stateLock.withLock { stopped = true }
    }

    func respond(_ json: String, status: Int = 200) {
        guard !stateLock.withLock({ stopped }) else {
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

private final class FeedTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date()
    var now: Date {
        lock.withLock { date }
    }

    func advance(_ seconds: TimeInterval) {
        lock.withLock { date.addTimeInterval(seconds) }
    }
}
