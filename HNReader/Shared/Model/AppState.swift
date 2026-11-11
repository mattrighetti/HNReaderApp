import Foundation
import Observation

enum ArticleFont: String, CaseIterable, Hashable, Identifiable {
    case charis = "charis"
    case ibmPlexSerif = "ibm-plex-serif"
    case sourceSerif = "source-serif-4"
    case literata = "literata"
    case notoSerif = "noto-serif"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .charis:
            return "Charis SIL"
        case .ibmPlexSerif:
            return "IBM Plex Serif"
        case .sourceSerif:
            return "Source Serif 4"
        case .literata:
            return "Literata"
        case .notoSerif:
            return "Noto Serif"
        }
    }

    /// PostScript font name used by the native HTML renderer.
    var fontName: String {
        switch self {
        case .charis:
            return "Charis-Regular"
        case .ibmPlexSerif:
            return "IBMPlexSerif-Regular"
        case .sourceSerif:
            return "SourceSerif4Roman-Regular"
        case .literata:
            return "Literata-Regular"
        case .notoSerif:
            return "NotoSerif-Regular"
        }
    }

    /// Explicit heading faces avoid requesting weights that a bundled font does not support.
    var titleFontName: String {
        switch self {
        case .charis:
            return "Charis-Bold"
        case .ibmPlexSerif:
            return "IBMPlexSerif-SemiBold"
        case .sourceSerif:
            return "SourceSerif4Roman-SemiBold"
        case .literata:
            return "Literata-Regular_SemiBold"
        case .notoSerif:
            return "NotoSerif-SemiBold"
        }
    }
}

@MainActor
@Observable
final class AppState {
    private(set) var savedItems: [Item]
    private(set) var readIDs: Set<Int>
    var articleFont: ArticleFont {
        didSet { defaults.set(articleFont.rawValue, forKey: "articleFont") }
    }

    #if os(iOS)
        struct StoryLink: Equatable {
            let id = UUID()
            let itemID: Int
        }

        var incomingStoryLink: StoryLink?
    #endif

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Keep the existing key for compatibility; Item stores stories and comments.
        savedItems =
            defaults.data(forKey: "savedStories")
            .flatMap { try? JSONDecoder().decode([Item].self, from: $0) } ?? []
        readIDs = Set(defaults.array(forKey: "readStories") as? [Int] ?? [])
        articleFont = ArticleFont(
            rawValue: defaults.string(forKey: "articleFont") ?? "charis"
        ) ?? .charis
    }

    func isSaved(_ item: Item) -> Bool {
        savedItems.contains { $0.id == item.id }
    }

    func toggleSaved(_ item: Item) {
        if isSaved(item) {
            savedItems.removeAll { $0.id == item.id }
        } else {
            savedItems.insert(item, at: 0)
        }

        if let data = try? JSONEncoder().encode(savedItems) {
            defaults.set(data, forKey: "savedStories")
        }
    }

    func markRead(_ item: Item) {
        guard readIDs.insert(item.id).inserted else {
            return
        }

        defaults.set(Array(readIDs), forKey: "readStories")
    }

    enum SidebarSelection: String, CaseIterable, Identifiable {
        case top = "Top Stories"
        case new = "Latest"
        case best = "Best"
        case ask = "Ask HN"
        case show = "Show HN"
        case job = "Jobs"
        case saved = "Saved"

        var id: String {
            rawValue
        }

        var category: HackerNews.API.Stories? {
            switch self {
            case .top:
                return .top
            case .new:
                return .new
            case .best:
                return .best
            case .ask:
                return .ask
            case .show:
                return .show
            case .job:
                return .job
            case .saved:
                return nil
            }
        }

        var subtitle: String {
            switch self {
            case .top:
                return "What the community is reading"
            case .new:
                return "Fresh from the community"
            case .best:
                return "Stories worth your time"
            case .ask:
                return "Questions, ideas, and conversations"
            case .show:
                return "Made by the community"
            case .job:
                return "Find your next chapter"
            case .saved:
                return "Good reads, kept for later"
            }
        }

        var iconName: String {
            switch self {
            case .top:
                return "flame"
            case .new:
                return "clock"
            case .best:
                return "star"
            case .ask:
                return "bubble.left.and.bubble.right"
            case .show:
                return "sparkles"
            case .job:
                return "briefcase"
            case .saved:
                return "bookmark"
            }
        }
    }
}
