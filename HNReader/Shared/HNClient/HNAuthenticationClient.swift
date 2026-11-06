import Foundation

struct HNAuthenticatedAccount: Equatable, Sendable {
    let username: String
}

enum HNAuthenticationError: Error, Equatable, Sendable {
    case credentialsRequired
    case invalidCredentials
    case validationRequired
    case invalidResponse
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

    private let session: URLSession
    private let cookieStorage: HTTPCookieStorage
    private let loginURL: URL

    init(
        session: URLSession = .shared,
        cookieStorage: HTTPCookieStorage = .shared,
        loginURL: URL = URL(string: "https://news.ycombinator.com/login")!
    ) {
        self.session = session
        self.cookieStorage = cookieStorage
        self.loginURL = loginURL
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

            return HNAuthenticatedAccount(username: username)
        } catch {
            replaceAuthenticationCookies(with: previousCookies)
            throw error
        }
    }

    func hasActiveSession() -> Bool {
        !authenticationCookies.isEmpty
    }

    /// Removes the local session. Hacker News credentials are never retained by this client.
    func logout() {
        replaceAuthenticationCookies(with: [])
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
