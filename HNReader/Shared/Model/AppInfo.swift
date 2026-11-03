import Foundation

enum AppInfo {
    static let repositoryURL = URL(string: "https://github.com/mattrighetti/HNReaderApp")!
    static let authorURL = URL(string: "https://github.com/mattrighetti")!
    static let hackerNewsURL = URL(string: "https://news.ycombinator.com")!

    static var versionDescription: String {
        let info = Bundle.main.infoDictionary

        guard let version = info?["CFBundleShortVersionString"] as? String else {
            return "Development build"
        }

        if let build = info?["CFBundleVersion"] as? String {
            return "Version \(version) (\(build))"
        }

        return "Version \(version)"
    }
}
