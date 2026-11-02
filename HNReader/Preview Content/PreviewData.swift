#if DEBUG
import SwiftUI

/// Shared local fixtures for Canvas. Preview state uses an isolated defaults suite.
@MainActor
enum PreviewData {
    static let stories: [Item] = {
        let posted = Int(Date().addingTimeInterval(-7200).timeIntervalSince1970)
        let examples = """
        [
            {
                "id": 1,
                "by": "movq",
                "title": "Novellas with Groff",
                "url": "https://movq.de",
                "score": 34,
                "descendants": 6,
                "kids": [400, 450],
                "time": \(posted)
            },
            {
                "id": 2,
                "by": "ninchi",
                "title": "Work, Art, and Study: AI and Ownership",
                "url": "https://ninchi.substack.com",
                "score": 128,
                "descendants": 42,
                "time": \(posted)
            },
            {
                "id": 3,
                "by": "compilerfan",
                "title": "A surprisingly small compiler, built from first principles and a little curiosity",
                "url": "https://example.com",
                "score": 256,
                "descendants": 61,
                "time": \(posted)
            }
        ]
        """

        return decode(examples)
    }()

    static let comments: [Item] = {
        let posted = Int(Date().addingTimeInterval(-3600).timeIntervalSince1970)
        let examples = """
        [
            {
                "id": 400,
                "by": "alex",
                "text": "The best interfaces make the conversation easy to follow. Small details like spacing and thread lines make a surprisingly big difference.",
                "kids": [401, 402],
                "time": \(posted)
            },
            {
                "id": 401,
                "parent": 400,
                "by": "samantha",
                "text": "Agreed. I especially like being able to collapse a whole branch without losing my place in the discussion.",
                "kids": [403],
                "time": \(posted + 600)
            },
            {
                "id": 402,
                "parent": 400,
                "by": "kai",
                "text": "And keeping the text readable as the thread gets deeper. A little indentation goes a long way.",
                "time": \(posted + 1200)
            },
            {
                "id": 403,
                "parent": 401,
                "by": "alex",
                "text": "Exactly. The curved connectors should show <i>who is replying to whom</i>, without making the text feel boxed in.",
                "kids": [404],
                "time": \(posted + 900)
            },
            {
                "id": 404,
                "parent": 403,
                "by": "jules",
                "text": "This feels much easier to scan. The author badge helps too.",
                "time": \(posted + 1500)
            },
            {
                "id": 450,
                "by": "taylor",
                "text": "A separate top-level thought: sharing a direct link to a comment is useful when a conversation has a lot of branches.",
                "time": \(posted + 1800)
            }
        ]
        """

        return decode(examples)
    }()

    static var rows: [StoryRow] {
        stories.enumerated().map { index, item in
            StoryRow(rank: index + 1, item: item)
        }
    }

    static var rootComments: [Item] {
        comments.filter { $0.parent == nil }
    }

    static var threads: [Int: [Item]] {
        let byID = Dictionary(uniqueKeysWithValues: comments.map { ($0.id, $0) })

        return Dictionary(uniqueKeysWithValues: comments.map { comment in
            (comment.id, (comment.kids ?? []).compactMap { byID[$0] })
        })
    }

    static func appState(
        selection: AppState.SidebarSelection = .top,
        theme: AppState.DisplayMode = .system,
        includeSavedStories: Bool = true
    ) -> AppState {
        let suite = "HNReader.Canvas.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let state = AppState(defaults: defaults)
        state.sidebarSelection = selection
        state.displayMode = theme

        if let last = stories.last {
            state.markRead(last)
        }

        if includeSavedStories {
            for story in stories.prefix(2) {
                state.toggleSaved(story)
            }
        }

        defaults.removePersistentDomain(forName: suite)

        return state
    }

    private static func decode(_ json: String) -> [Item] {
        do {
            return try JSONDecoder().decode([Item].self, from: Data(json.utf8))
        } catch {
            assertionFailure("Invalid Canvas fixture: \(error)")
            return []
        }
    }
}
#endif
