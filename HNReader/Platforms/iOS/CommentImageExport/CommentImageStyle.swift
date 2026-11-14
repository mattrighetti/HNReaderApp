import UIKit

struct CommentImageStyle: Equatable, Hashable {
    static let logoAssetName = "IconPreviewOrange"

    enum Palette: String, CaseIterable, Identifiable {
        case paper = "Paper", midnight = "Midnight", forest = "Forest", plum = "Plum"

        var id: Self { self }

        var background: UIColor {
            switch self {
            case .paper: return UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
            case .midnight: return UIColor(red: 0.07, green: 0.10, blue: 0.17, alpha: 1)
            case .forest: return UIColor(red: 0.06, green: 0.19, blue: 0.15, alpha: 1)
            case .plum: return UIColor(red: 0.23, green: 0.10, blue: 0.20, alpha: 1)
            }
        }

        var ink: UIColor {
            switch self {
            case .paper: return UIColor(red: 0.16, green: 0.15, blue: 0.14, alpha: 1)
            case .midnight, .forest: return UIColor(red: 0.98, green: 0.95, blue: 0.87, alpha: 1)
            case .plum: return UIColor(red: 1, green: 0.91, blue: 0.95, alpha: 1)
            }
        }
    }

    var palette: Palette = .paper
    var watermark = true
    var includeUsername = true
    var includeArticleTitle = false

    var ink: UIColor { palette.ink }
}

struct CommentImageSnapshot: Identifiable {
    let id: Int
    let author: String
    let html: String
    let url: URL
    let articleTitle: String?
    let sourceComment: Item?

    static func normalizedTitle(_ title: String?) -> String? {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines),
            !title.isEmpty else { return nil }
        return title
    }

    static func canExport(_ item: Item) -> Bool {
        guard item.isVisibleComment, let html = item.text else { return false }
        // Cheap menu eligibility check. The formatter validates the decoded text
        // again before rendering, including less common whitespace entities.
        let text = html.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#160;", with: " ")
            .replacingOccurrences(of: "&#xA0;", with: " ", options: .caseInsensitive)
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(item: Item, articleTitle: String? = nil) {
        id = item.id
        author = item.by ?? "Deleted user"
        html = item.text ?? ""
        url = item.discussionURL
        self.articleTitle = Self.normalizedTitle(articleTitle)
        sourceComment = item
    }

    init(id: Int, author: String, html: String, articleTitle: String? = nil) {
        self.id = id
        self.author = author
        self.html = html
        url = URL(string: "https://news.ycombinator.com/item?id=\(id)")!
        self.articleTitle = Self.normalizedTitle(articleTitle)
        sourceComment = nil
    }
}
