import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private(set) var savedItems: [Item]
    private(set) var readIDs: Set<Int>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Keep the existing key for compatibility; Item stores stories and comments.
        savedItems =
            defaults.data(forKey: "savedStories")
            .flatMap { try? JSONDecoder().decode([Item].self, from: $0) } ?? []
        readIDs = Set(defaults.array(forKey: "readStories") as? [Int] ?? [])
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
