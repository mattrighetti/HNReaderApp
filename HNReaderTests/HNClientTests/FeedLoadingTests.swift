import SwiftUI
import XCTest
@testable import HNReader

final class FeedLoadingTests: XCTestCase {
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

    @MainActor
    func testPagesAppearAtomicallyInGroupsOfThirty() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        server.respond("/v0/topstories.json", json: "[\((1...65).map(String.init).joined(separator: ","))]")
        server.hold(["/v0/item/30.json", "/v0/item/60.json"])

        let firstReady = expectation(description: "First page waits for its last story")
        let secondReady = expectation(description: "Second page waits for its last story")

        server.observe { path in
            if path == "/v0/item/30.json" {
                firstReady.fulfill()
            }

            if path == "/v0/item/60.json" {
                secondReady.fulfill()
            }
        }

        let model = ItemListViewModel(service: NewsService(session: server.session))
        let first = Task { await model.load(.top) }
        await fulfillment(of: [firstReady], timeout: 3)

        XCTAssertTrue(model.rows.isEmpty)
        XCTAssertTrue(model.isLoading)
        XCTAssertEqual(server.count("/v0/item/31.json"), 0)

        server.release("/v0/item/30.json")
        await first.value

        XCTAssertEqual(model.stories.map(\.id), Array(1...30))
        XCTAssertTrue(model.hasMore)

        let second = Task { await model.loadMore() }
        await fulfillment(of: [secondReady], timeout: 3)

        XCTAssertEqual(model.stories.map(\.id), Array(1...30))
        XCTAssertTrue(model.isLoadingMore)
        XCTAssertEqual(server.count("/v0/item/61.json"), 0)

        await model.loadMore()
        XCTAssertEqual(server.count("/v0/item/31.json"), 1, "Repeated footer events must not duplicate a page")

        server.release("/v0/item/60.json")
        await second.value

        XCTAssertEqual(model.stories.map(\.id), Array(1...60))

        await model.loadMore()

        XCTAssertEqual(model.stories.map(\.id), Array(1...65))
        XCTAssertEqual(model.rows.map(\.rank), Array(1...65))
        XCTAssertFalse(model.hasMore)
    }

    @MainActor
    func testSectionCacheRestoresAllLoadedPagesAndOffset() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        server.respond("/v0/beststories.json", json: "[1]")

        let model = ItemListViewModel(service: NewsService(session: server.session))
        await model.load(.top)
        await model.loadMore()
        await model.load(.best)

        XCTAssertEqual(server.count("/v0/item/1.json"), 1)

        let requests = server.totalRequests
        await model.load(.top)
        await model.loadMore()

        XCTAssertEqual(server.totalRequests, requests)
        XCTAssertEqual(model.stories.map(\.id), Array(1...40))
        XCTAssertFalse(model.hasMore)

        await model.load(.top, forceRefresh: true)

        XCTAssertEqual(model.rows.count, 30)
        XCTAssertEqual(server.count("/v0/topstories.json"), 2)
        XCTAssertEqual(server.count("/v0/item/1.json"), 2)
    }

    @MainActor
    func testFailedPageKeepsExistingRowsAndCanBeRetried() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        let model = ItemListViewModel(service: NewsService(session: server.session))
        await model.load(.top)

        server.respond("/v0/item/35.json", json: "{}", status: 500)
        await model.loadMore()

        XCTAssertEqual(model.stories.map(\.id), Array(1...30))
        XCTAssertNotNil(model.paginationError)
        XCTAssertFalse(model.isLoadingMore)
        XCTAssertTrue(model.hasMore)

        server.respond("/v0/item/35.json", json: #"{"id":35,"title":"Recovered"}"#)
        await model.loadMore()

        XCTAssertEqual(model.stories.map(\.id), Array(1...40))
        XCTAssertNil(model.paginationError)
        XCTAssertFalse(model.hasMore)
    }

    @MainActor
    func testMissingStoriesAdvanceByRequestedIDsAndPreserveRank() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        server.respond("/v0/item/2.json", json: "null")
        server.respond("/v0/item/3.json", json: #"{"id":3,"deleted":true}"#)

        let model = ItemListViewModel(service: NewsService(session: server.session))
        await model.load(.top)
        await model.loadMore()

        XCTAssertEqual(model.stories.map(\.id), [1] + Array(4...40))
        XCTAssertEqual(model.rows.map(\.rank), [1] + Array(4...40))
        XCTAssertEqual(server.count("/v0/item/30.json"), 1)
        XCTAssertFalse(model.hasMore)
    }

    @MainActor
    func testStaleSectionRemainsVisibleIfRefreshFails() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        let clock = FeedTestClock()
        let model = ItemListViewModel(service: NewsService(session: server.session), now: { clock.now })
        await model.load(.top)

        let cached = model.stories
        clock.advance(61)
        server.respond("/v0/topstories.json", json: "{}", status: 500)
        await model.load(.top)

        XCTAssertEqual(model.stories, cached)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testLatePageCannotOverwriteAnotherSection() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        server.respond("/v0/beststories.json", json: "[101]")
        server.hold(["/v0/item/31.json"])

        let started = expectation(description: "Next page in flight")
        server.observe { path in
            if path == "/v0/item/31.json" {
                started.fulfill()
            }
        }

        let model = ItemListViewModel(service: NewsService(session: server.session))
        await model.load(.top)

        let old = Task { await model.loadMore() }
        await fulfillment(of: [started], timeout: 3)
        await model.load(.best)

        server.releaseAll()
        await old.value

        XCTAssertEqual(model.stories.map(\.id), [101])
        XCTAssertNil(model.errorMessage)
        XCTAssertNil(model.paginationError)
        XCTAssertFalse(model.isLoadingMore)
    }

    @MainActor
    func testEmptyFeedDoesNotRequestItemsOrFurtherPages() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        server.respond("/v0/topstories.json", json: "[]")

        let model = ItemListViewModel(service: NewsService(session: server.session))
        await model.load(.top)
        await model.loadMore()

        XCTAssertTrue(model.rows.isEmpty)
        XCTAssertFalse(model.hasMore)
        XCTAssertEqual(server.totalRequests, 1)
    }

    @MainActor
    func testNativeListLoadsNextPageOnlyAtBottom() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        server.respond("/v0/topstories.json", json: "[\((1...65).map(String.init).joined(separator: ","))]")

        let pageTwo = expectation(description: "Second page requested at bottom")
        let pageThree = expectation(description: "Final page requested on next scroll")

        server.observe { path in
            if path == "/v0/item/60.json" {
                pageTwo.fulfill()
            }

            if path == "/v0/item/65.json" {
                pageThree.fulfill()
            }
        }

        let model = ItemListViewModel(service: NewsService(session: server.session))
        await model.load(.top)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 650),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: FeedPageHarness(model: model).environmentObject(AppState()))

        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertEqual(model.rows.count, 30)
        XCTAssertEqual(server.count("/v0/item/31.json"), 0)

        let scroll = try XCTUnwrap(Self.tableScrollView(in: try XCTUnwrap(window.contentView)))
        Self.scrollToBottom(scroll)
        await fulfillment(of: [pageTwo], timeout: 3)
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertEqual(model.rows.count, 60)
        XCTAssertEqual(server.count("/v0/item/61.json"), 0)

        Self.scrollToBottom(scroll)
        await fulfillment(of: [pageThree], timeout: 3)
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertEqual(model.rows.count, 65)
        XCTAssertFalse(model.hasMore)
    }

    @MainActor
    func testRepliesLoadOnDemandInPagesAndReuseTheItemCache() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        let json = "{\"id\":900,\"kids\":[\((1...31).map(String.init).joined(separator: ","))]}"
        let parent = try JSONDecoder().decode(Item.self, from: Data(json.utf8))
        let service = NewsService(session: server.session)
        let model = CommentRepliesModel(item: parent, service: service)

        XCTAssertEqual(server.totalRequests, 0)
        XCTAssertTrue(model.hasMore)

        await model.loadNextPage()

        XCTAssertEqual(model.replies.map(\.id), Array(1...15))
        XCTAssertTrue(model.hasLoaded)
        XCTAssertEqual(server.count("/v0/item/16.json"), 0)

        await model.loadNextPage()
        await model.loadNextPage()

        XCTAssertEqual(model.replies.map(\.id), Array(1...31))
        XCTAssertFalse(model.hasMore)

        let anotherView = CommentRepliesModel(item: parent, service: service)
        await anotherView.loadNextPage()

        XCTAssertEqual(anotherView.replies.count, 15)
        XCTAssertEqual(server.totalRequests, 31)
    }

    @MainActor
    func testFailedRepliesCanBeRetriedWithoutAdvancingThePage() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        let parent = try JSONDecoder().decode(Item.self, from: Data(#"{"id":900,"kids":[1,2]}"#.utf8))
        let model = CommentRepliesModel(item: parent, service: NewsService(session: server.session))

        server.respond("/v0/item/2.json", json: "{}", status: 500)
        await model.loadNextPage()

        XCTAssertTrue(model.replies.isEmpty)
        XCTAssertFalse(model.hasLoaded)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.hasMore)

        server.respond("/v0/item/2.json", json: #"{"id":2}"#)
        await model.loadNextPage()

        XCTAssertEqual(model.replies.map(\.id), [1, 2])
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.hasMore)
    }

    @MainActor
    func testCancelledRepliesDoNotAdvanceAndCanBeReopened() async throws {
        let server = FeedTestServer()
        defer { server.close() }

        let parent = try JSONDecoder().decode(Item.self, from: Data(#"{"id":900,"kids":[1]}"#.utf8))
        let model = CommentRepliesModel(item: parent, service: NewsService(session: server.session))
        let started = expectation(description: "Reply request started")

        server.hold(["/v0/item/1.json"])
        server.observe { _ in started.fulfill() }

        let task = Task { await model.loadNextPage() }
        await fulfillment(of: [started], timeout: 3)
        task.cancel()
        await task.value

        XCTAssertTrue(model.replies.isEmpty)
        XCTAssertFalse(model.hasLoaded)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)

        server.observe { _ in }
        server.releaseAll()
        await model.loadNextPage()

        XCTAssertEqual(model.replies.map(\.id), [1])
        XCTAssertFalse(model.hasMore)
    }

    func testCacheCanBeClearedAndPreservesLargeIDs() throws {
        let cache = ItemCache()
        let item = try JSONDecoder().decode(Item.self, from: Data(#"{"id":4294967297}"#.utf8))

        cache.insert(item)

        XCTAssertEqual(cache.item(id: item.id), item)
        XCTAssertNil(cache.item(id: 1))

        cache.removeAll()

        XCTAssertNil(cache.item(id: item.id))
    }

    @MainActor
    private static func tableScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView, scroll.documentView is NSTableView {
            return scroll
        }

        return view.subviews.lazy.compactMap { tableScrollView(in: $0) }.first
    }

    @MainActor
    private static func scrollToBottom(_ scroll: NSScrollView) {
        guard let document = scroll.documentView else {
            return
        }

        scroll.contentView.scroll(to: NSPoint(x: 0, y: document.bounds.height - scroll.contentSize.height))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
}

private struct FeedPageHarness: View {
    @ObservedObject var model: ItemListViewModel

    @State private var selection: Int?
    @State private var unreadOnly = false

    var body: some View {
        ItemList(
            rows: model.rows,
            revision: model.revision,
            selectedID: $selection,
            title: "Top Stories",
            subtitle: "Test feed",
            isLoading: model.isLoading,
            isLoadingMore: model.isLoadingMore,
            hasMore: model.hasMore,
            paginationError: model.paginationError,
            errorMessage: model.errorMessage,
            isSaved: false,
            isSearching: false,
            unreadOnly: $unreadOnly,
            refresh: {},
            loadMore: { await model.loadMore() }
        )
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

    func observe(_ callback: @escaping @Sendable (String) -> Void) {
        lock.withLock { observer = callback } }

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

    func release(_ path: String) {
        let request = lock.withLock { pending.removeValue(forKey: path) }
        if let request {
            reply(request)
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
        _ = lock.withLock { handlers.removeValue(forKey: token) } }

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
