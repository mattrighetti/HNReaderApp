import UIKit

/// Draws the complete card directly with TextKit, independently of screen size,
/// appearance, Dynamic Type, and the interactive comment's collapsed state.
@MainActor
enum CommentImageRenderer {
    static let width: CGFloat = 360
    static let scale: CGFloat = 3
    static let maximumPixelHeight: CGFloat = 4096
    private static let inset: CGFloat = 28

    enum Failure: LocalizedError, Equatable {
        case empty, tooLong, encoding, articleTitleUnavailable

        var errorDescription: String? {
            switch self {
            case .empty: return "This comment has no text to share."
            case .tooLong: return "This comment is too long for one image."
            case .encoding: return "The comment image could not be created. Please try again."
            case .articleTitleUnavailable:
                return "The article title couldn’t be loaded. Try again, or turn off Include article title."
            }
        }
    }

    struct Output {
        let image: UIImage
        let png: Data
        let text: String
    }

    static func format(_ snapshot: CommentImageSnapshot) async throws -> NSAttributedString {
        let text = await CommentTextFormatter.render(html: snapshot.html, fontSize: 16, lineSpacing: 5)
        try Task.checkCancellation()
        guard !text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Failure.empty
        }
        return text
    }

    static func render(
        snapshot: CommentImageSnapshot, formatted: NSAttributedString, style: CommentImageStyle,
        articleTitle: String? = nil
    ) throws -> Output {
        guard !formatted.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Failure.empty
        }
        let body = NSMutableAttributedString(attributedString: formatted)
        let fullRange = NSRange(location: 0, length: body.length)
        body.addAttribute(.foregroundColor, value: style.ink, range: fullRange)
        body.removeAttribute(.backgroundColor, range: fullRange)
        body.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
            let paragraph = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.tailIndent = 0
            body.addAttribute(.paragraphStyle, value: paragraph, range: range)
        }
        body.enumerateAttribute(.link, in: fullRange) { value, range, _ in
            if value != nil {
                body.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
        // TextKit applies system link blue at drawing time while .link remains.
        // The bitmap needs underlined text in the selected ink, with no interaction.
        body.removeAttribute(.link, range: fullRange)

        let source = layout(text("HACKER NEWS", size: 10, weight: .bold, color: style.ink))
        let title: TextLayout?
        if style.includeArticleTitle {
            guard let value = CommentImageSnapshot.normalizedTitle(articleTitle ?? snapshot.articleTitle) else {
                throw Failure.articleTitleUnavailable
            }
            title = layout(text(value, size: 16, weight: .semibold, color: style.ink))
        } else {
            title = nil
        }
        let author = layout(text(snapshot.author, size: 14, weight: .semibold, color: style.ink))
        let content = layout(body)
        let logoSize: CGFloat = 24
        let branding = TextLayout(
            text("Shared with HNReader", size: 11, color: style.ink),
            width: width - inset * 2 - logoSize - 8
        )
        let logo = UIImage(named: CommentImageStyle.logoAssetName)
        if style.watermark, logo == nil { throw Failure.encoding }

        let sourceY = inset
        let titleY = sourceY + source.height + 10
        let headerBottom = title.map { titleY + $0.height } ?? (sourceY + source.height)
        let authorY = headerBottom + 10
        let bodyY = (style.includeUsername ? authorY + author.height : headerBottom) + 24
        let contentBottom = bodyY + content.height
        let brandingY = contentBottom + 16
        let brandingHeight = max(logoSize, branding.height)
        let height = ceil((style.watermark ? brandingY + brandingHeight : contentBottom) + inset)
        guard height.isFinite, height * scale <= maximumPixelHeight else { throw Failure.tooLong }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let png = renderer.pngData { context in
            style.palette.background.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            source.draw(at: CGPoint(x: inset, y: sourceY))
            title?.draw(at: CGPoint(x: inset, y: titleY))
            if style.includeUsername { author.draw(at: CGPoint(x: inset, y: authorY)) }
            content.draw(at: CGPoint(x: inset, y: bodyY), quoteColor: style.ink)
            if style.watermark, let logo {
                let logoRect = CGRect(
                    x: inset, y: brandingY + (brandingHeight - logoSize) / 2,
                    width: logoSize, height: logoSize)
                context.cgContext.saveGState()
                UIBezierPath(roundedRect: logoRect, cornerRadius: 6).addClip()
                logo.draw(in: logoRect)
                context.cgContext.restoreGState()
                branding.draw(at: CGPoint(
                    x: inset + logoSize + 8, y: brandingY + (brandingHeight - branding.height) / 2))
            }
        }
        guard let image = UIImage(data: png, scale: scale) else { throw Failure.encoding }
        return Output(image: image, png: png, text: formatted.string)
    }

    private static func text(
        _ value: String, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor
    ) -> NSAttributedString {
        NSAttributedString(string: value, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color,
        ])
    }

    private static func layout(_ text: NSAttributedString) -> TextLayout {
        TextLayout(text, width: width - inset * 2)
    }

    private final class TextLayout {
        let storage: NSTextStorage
        let manager = NSLayoutManager()
        let container: NSTextContainer
        let height: CGFloat

        init(_ text: NSAttributedString, width: CGFloat) {
            storage = NSTextStorage(attributedString: text)
            container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
            container.lineFragmentPadding = 0
            storage.addLayoutManager(manager)
            manager.addTextContainer(container)
            manager.ensureLayout(for: container)
            height = ceil(manager.usedRect(for: container).maxY)
        }

        func draw(at origin: CGPoint, quoteColor: UIColor? = nil) {
            let glyphs = manager.glyphRange(for: container)
            if let quoteColor {
                storage.enumerateAttribute(
                    .hackerNewsQuote, in: NSRange(location: 0, length: storage.length)
                ) { value, range, _ in
                    guard value != nil else { return }
                    let quoteGlyphs = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                    let bounds = manager.boundingRect(forGlyphRange: quoteGlyphs, in: container)
                    quoteColor.withAlphaComponent(0.7).setFill()
                    UIBezierPath(roundedRect: CGRect(
                        x: origin.x + 1, y: origin.y + bounds.minY + 1,
                        width: 3, height: max(3, bounds.height - 2)
                    ), cornerRadius: 1.5).fill()
                }
            }
            manager.drawBackground(forGlyphRange: glyphs, at: origin)
            manager.drawGlyphs(forGlyphRange: glyphs, at: origin)
        }
    }
}
