import Foundation

struct HNAuthenticatedAccount: Equatable, Sendable {
    let username: String
}

enum HNUpvoteKind: String, CaseIterable, Identifiable, Sendable {
    case submissions
    case comments

    var id: Self { self }

    var title: String {
        switch self {
        case .submissions: "Stories"
        case .comments: "Comments"
        }
    }
}

struct HNUpvotedPage: Equatable, Sendable {
    let ids: [Int]
    let hasMore: Bool
}

enum HNAuthenticationError: Error, Equatable, Sendable {
    case credentialsRequired
    case invalidCredentials
    case validationRequired
    case invalidResponse
    case notAuthenticated
    case server(statusCode: Int)
}

extension HNAuthenticationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .credentialsRequired:
            return "Enter your Hacker News username and password."
        case .invalidCredentials:
            return "The Hacker News username or password is incorrect."
        case .validationRequired:
            return "Hacker News requires additional validation before signing in."
        case .invalidResponse:
            return "Hacker News returned an unexpected response."
        case .notAuthenticated:
            return "Your Hacker News session has expired. Sign in again to view your upvotes."
        case .server(let statusCode):
            return "Hacker News could not sign you in (HTTP \(statusCode))."
        }
    }
}

/// Authenticates against the Hacker News website and owns its session cookie.
///
/// Hacker News does not expose authentication through its Firebase API. Its website accepts
/// form-encoded credentials and establishes a session with a cookie named `user`.
actor HNAuthenticationClient {
    static let shared = HNAuthenticationClient()

    private static let sessionCookieName = "user"
    private static let usernameDefaultsKey = "hnAuthenticationUsername"

    private let session: URLSession
    private let cookieStorage: HTTPCookieStorage
    private let loginURL: URL
    private let defaults: UserDefaults

    init(
        session: URLSession = .shared,
        cookieStorage: HTTPCookieStorage = .shared,
        loginURL: URL = URL(string: "https://news.ycombinator.com/login")!,
        defaults: UserDefaults = .standard
    ) {
        self.session = session
        self.cookieStorage = cookieStorage
        self.loginURL = loginURL
        self.defaults = defaults
    }

    func login(username: String, password: String) async throws -> HNAuthenticatedAccount {
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty, !password.isEmpty else {
            throw HNAuthenticationError.credentialsRequired
        }

        // A stale cookie must not make a failed request look successful. Preserve it so a typo
        // while switching accounts does not destroy the caller's existing session.
        let previousCookies = authenticationCookies
        replaceAuthenticationCookies(with: [])

        do {
            var request = URLRequest(
                url: loginURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 20
            )
            request.httpMethod = "POST"
            request.httpShouldHandleCookies = true
            request.setValue(
                "application/x-www-form-urlencoded; charset=utf-8",
                forHTTPHeaderField: "Content-Type"
            )
            request.setValue("text/html", forHTTPHeaderField: "Accept")
            request.setValue(loginURL.absoluteString, forHTTPHeaderField: "Referer")
            if let origin = origin(for: loginURL) {
                request.setValue(origin, forHTTPHeaderField: "Origin")
            }
            request.httpBody = formBody(username: username, password: password)

            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw HNAuthenticationError.invalidResponse
            }

            captureCookies(from: response)

            guard (200 ..< 400).contains(response.statusCode) else {
                throw HNAuthenticationError.server(statusCode: response.statusCode)
            }

            guard !authenticationCookies.isEmpty else {
                throw classifyFailedLogin(data)
            }

            defaults.set(username, forKey: Self.usernameDefaultsKey)
            return HNAuthenticatedAccount(username: username)
        } catch {
            replaceAuthenticationCookies(with: previousCookies)
            throw error
        }
    }

    func hasActiveSession() -> Bool {
        !authenticationCookies.isEmpty
    }

    func currentAccount() -> HNAuthenticatedAccount? {
        guard !authenticationCookies.isEmpty else {
            defaults.removeObject(forKey: Self.usernameDefaultsKey)
            return nil
        }

        guard
            let username = defaults.string(forKey: Self.usernameDefaultsKey),
            !username.isEmpty
        else {
            return nil
        }

        return HNAuthenticatedAccount(username: username)
    }

    func upvotedItems(
        username: String,
        kind: HNUpvoteKind,
        page: Int = 1
    ) async throws -> HNUpvotedPage {
        guard let account = currentAccount(), account.username == username else {
            throw HNAuthenticationError.notAuthenticated
        }

        var components = URLComponents(
            url: loginURL.deletingLastPathComponent().appendingPathComponent("upvoted"),
            resolvingAgainstBaseURL: false
        )
        var queryItems = [URLQueryItem(name: "id", value: username)]
        if kind == .comments {
            queryItems.append(URLQueryItem(name: "comments", value: "t"))
        }
        if page > 1 {
            queryItems.append(URLQueryItem(name: "p", value: String(page)))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw HNAuthenticationError.invalidResponse
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 20
        )
        request.httpShouldHandleCookies = true
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw HNAuthenticationError.invalidResponse
        }
        captureCookies(from: response)

        guard (200 ..< 300).contains(response.statusCode) else {
            throw HNAuthenticationError.server(statusCode: response.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw HNAuthenticationError.invalidResponse
        }
        guard !isLoginPage(html, responseURL: response.url) else {
            throw HNAuthenticationError.notAuthenticated
        }

        return HNUpvotedPage(
            ids: itemIDs(in: html),
            hasMore: containsMoreLink(in: html)
        )
    }

    /// Removes the local session. Hacker News credentials are never retained by this client.
    func logout() {
        replaceAuthenticationCookies(with: [])
        defaults.removeObject(forKey: Self.usernameDefaultsKey)
    }

    private var authenticationCookies: [HTTPCookie] {
        cookieStorage.cookies?.filter { cookie in
            cookie.name == Self.sessionCookieName
                && !cookie.value.isEmpty
                && domain(cookie.domain, matchesHost: loginURL.host)
        } ?? []
    }

    private func replaceAuthenticationCookies(with cookies: [HTTPCookie]) {
        authenticationCookies.forEach(cookieStorage.deleteCookie)
        cookies.forEach(cookieStorage.setCookie)
    }

    private func captureCookies(from response: HTTPURLResponse) {
        let fields = response.allHeaderFields.reduce(into: [String: String]()) { result, entry in
            guard let key = entry.key as? String, let value = entry.value as? String else {
                return
            }
            result[key] = value
        }

        let responseURL = response.url ?? loginURL
        HTTPCookie.cookies(withResponseHeaderFields: fields, for: responseURL)
            .forEach(cookieStorage.setCookie)
    }

    private func classifyFailedLogin(_ data: Data) -> HNAuthenticationError {
        guard let html = String(data: data, encoding: .utf8)?.lowercased() else {
            return .invalidResponse
        }

        if html.contains("validation required") || html.contains("g-recaptcha") {
            return .validationRequired
        }

        return .invalidCredentials
    }

    private func isLoginPage(_ html: String, responseURL: URL?) -> Bool {
        if responseURL?.lastPathComponent == "login" {
            return true
        }

        return html.range(
            of: #"<form[^>]+action=[\"']login[\"']"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private func itemIDs(in html: String) -> [Int] {
        let rowPattern = #"<tr\b[^>]*\bclass\s*=\s*[\"'][^\"']*\bathing\b[^\"']*[\"'][^>]*>"#
        let idPattern = #"\bid\s*=\s*[\"']([0-9]+)[\"']"#
        guard
            let rowExpression = try? NSRegularExpression(
                pattern: rowPattern,
                options: .caseInsensitive
            ),
            let idExpression = try? NSRegularExpression(
                pattern: idPattern,
                options: .caseInsensitive
            )
        else {
            return []
        }

        let range = NSRange(html.startIndex..., in: html)
        return rowExpression.matches(in: html, range: range).compactMap { rowMatch in
            guard
                let rowRange = Range(rowMatch.range, in: html),
                let idMatch = idExpression.firstMatch(
                    in: html,
                    range: NSRange(rowRange, in: html)
                ),
                idMatch.numberOfRanges > 1,
                let idRange = Range(idMatch.range(at: 1), in: html)
            else {
                return nil
            }
            return Int(html[idRange])
        }
    }

    private func containsMoreLink(in html: String) -> Bool {
        html.range(
            of: #"<a\b[^>]*\bclass\s*=\s*[\"'][^\"']*\bmorelink\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private func formBody(username: String, password: String) -> Data? {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "acct", value: username),
            URLQueryItem(name: "pw", value: password),
            URLQueryItem(name: "goto", value: "news"),
        ]
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    private func origin(for url: URL) -> String? {
        guard let scheme = url.scheme, let host = url.host else {
            return nil
        }

        if let port = url.port {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }

    private func domain(_ cookieDomain: String, matchesHost host: String?) -> Bool {
        guard let host else {
            return false
        }

        let normalizedHost = host.lowercased()
        let normalizedCookieDomain = cookieDomain
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        return normalizedHost == normalizedCookieDomain
            || normalizedHost.hasSuffix(".\(normalizedCookieDomain)")
    }
}
