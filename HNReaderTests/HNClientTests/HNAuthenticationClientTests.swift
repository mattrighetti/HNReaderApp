import XCTest

@testable import HNReader

final class HNAuthenticationClientTests: XCTestCase {
    private var cookieStorage: HTTPCookieStorage!
    private var session: URLSession!
    private let loginURL = URL(string: "https://auth.hnreader.test/login")!

    override func setUp() {
        super.setUp()

        cookieStorage = HTTPCookieStorage.sharedCookieStorage(
            forGroupContainerIdentifier: "HNAuthenticationClientTests-\(UUID().uuidString)"
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = cookieStorage
        configuration.protocolClasses = [HNAuthenticationTestProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        session = nil
        cookieStorage = nil
        HNAuthenticationTestProtocol.handler = nil
        super.tearDown()
    }

    func testLoginSubmitsEncodedCredentialsAndStoresSession() async throws {
        HNAuthenticationTestProtocol.handler = { [loginURL] request in
            XCTAssertEqual(request.url, loginURL)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Content-Type"),
                "application/x-www-form-urlencoded; charset=utf-8"
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://auth.hnreader.test")

            let fields = Self.formFields(in: request)
            XCTAssertEqual(fields["acct"], "alice")
            XCTAssertEqual(fields["pw"], "a password+&=")
            XCTAssertEqual(fields["goto"], "news")

            return Self.response(
                for: request,
                headers: ["Set-Cookie": "user=session-token; Path=/; Secure; HttpOnly"]
            )
        }

        let client = makeClient()
        let account = try await client.login(username: "  alice\n", password: "a password+&=")

        XCTAssertEqual(account, HNAuthenticatedAccount(username: "alice"))
        let hasActiveSession = await client.hasActiveSession()
        XCTAssertTrue(hasActiveSession)
        XCTAssertEqual(cookieStorage.cookies(for: loginURL)?.first { $0.name == "user" }?.value, "session-token")
    }

    func testMissingCredentialsDoesNotMakeARequest() async {
        HNAuthenticationTestProtocol.handler = { request in
            XCTFail("Unexpected request to \(request.url?.absoluteString ?? "unknown URL")")
            return Self.response(for: request)
        }

        let client = makeClient()

        await XCTAssertThrowsAuthenticationError(.credentialsRequired) {
            _ = try await client.login(username: " ", password: "password")
        }
        await XCTAssertThrowsAuthenticationError(.credentialsRequired) {
            _ = try await client.login(username: "alice", password: "")
        }
    }

    func testBadLoginIsReportedAsInvalidCredentials() async {
        HNAuthenticationTestProtocol.handler = { request in
            Self.response(for: request, body: "<html><body>Bad login.</body></html>")
        }

        let client = makeClient()
        await XCTAssertThrowsAuthenticationError(.invalidCredentials) {
            _ = try await client.login(username: "alice", password: "wrong")
        }
        let hasActiveSession = await client.hasActiveSession()
        XCTAssertFalse(hasActiveSession)
    }

    func testCaptchaResponseIsReportedAsValidationRequired() async {
        HNAuthenticationTestProtocol.handler = { request in
            Self.response(
                for: request,
                body: #"<html><body>Validation required.<div class="g-recaptcha"></div></body></html>"#
            )
        }

        let client = makeClient()
        await XCTAssertThrowsAuthenticationError(.validationRequired) {
            _ = try await client.login(username: "alice", password: "password")
        }
    }

    func testServerErrorIncludesStatusCode() async {
        HNAuthenticationTestProtocol.handler = { request in
            Self.response(for: request, statusCode: 503)
        }

        let client = makeClient()
        await XCTAssertThrowsAuthenticationError(.server(statusCode: 503)) {
            _ = try await client.login(username: "alice", password: "password")
        }
    }

    func testFailedLoginRestoresPreviousSession() async throws {
        let previousCookie = try XCTUnwrap(
            HTTPCookie(properties: [
                .domain: "auth.hnreader.test",
                .path: "/",
                .name: "user",
                .value: "previous-token",
                .secure: "TRUE",
            ])
        )
        cookieStorage.setCookie(previousCookie)
        HNAuthenticationTestProtocol.handler = { request in
            Self.response(for: request, body: "Bad login.")
        }

        let client = makeClient()
        await XCTAssertThrowsAuthenticationError(.invalidCredentials) {
            _ = try await client.login(username: "bob", password: "wrong")
        }

        XCTAssertEqual(cookieStorage.cookies(for: loginURL)?.first { $0.name == "user" }?.value, "previous-token")
        let hasActiveSession = await client.hasActiveSession()
        XCTAssertTrue(hasActiveSession)
    }

    func testLogoutRemovesOnlyHackerNewsSessionCookie() async throws {
        let authCookie = try XCTUnwrap(
            HTTPCookie(properties: [
                .domain: "auth.hnreader.test",
                .path: "/",
                .name: "user",
                .value: "session-token",
                .secure: "TRUE",
            ])
        )
        let unrelatedCookie = try XCTUnwrap(
            HTTPCookie(properties: [
                .domain: "auth.hnreader.test",
                .path: "/",
                .name: "preferences",
                .value: "compact",
                .secure: "TRUE",
            ])
        )
        cookieStorage.setCookie(authCookie)
        cookieStorage.setCookie(unrelatedCookie)

        let client = makeClient()
        await client.logout()

        let cookies = cookieStorage.cookies(for: loginURL) ?? []
        XCTAssertNil(cookies.first { $0.name == "user" })
        XCTAssertEqual(cookies.first { $0.name == "preferences" }?.value, "compact")
    }

    private func makeClient() -> HNAuthenticationClient {
        HNAuthenticationClient(
            session: session,
            cookieStorage: cookieStorage,
            loginURL: loginURL
        )
    }

    private func XCTAssertThrowsAuthenticationError(
        _ expectedError: HNAuthenticationError,
        operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expectedError)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? HNAuthenticationError, expectedError, file: file, line: line)
        }
    }

    private static func formFields(in request: URLRequest) -> [String: String] {
        guard
            let body = bodyData(in: request),
            let query = String(data: body, encoding: .utf8),
            let items = URLComponents(string: "?\(query)")?.queryItems
        else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }

    private static func bodyData(in request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else {
                return nil
            }
            if count == 0 {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }

    private static func response(
        for request: URLRequest,
        statusCode: Int = 200,
        headers: [String: String] = [:],
        body: String = "<html><body>signed in</body></html>"
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        return (response, Data(body.utf8))
    }
}

private final class HNAuthenticationTestProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            XCTFail("HNAuthenticationTestProtocol requires a handler")
            return
        }

        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
