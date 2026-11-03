import SwiftUI
#if os(iOS)
import UIKit
#endif

/// The independently previewable text portion of a Hacker News comment.
///
/// HN comment text arrives as HTML, most commonly using paragraphs, emphasis,
/// links, quote markers, and preformatted code. The iOS implementation uses a
/// selectable TextKit view so those formats can evolve independently from the
/// surrounding thread cell.
struct CommentTextView: View {
    let html: String
    var replyingTo: String?

    @State private var isExpanded = false

    private enum Metrics {
        #if os(macOS)
        static let bodyFontSize: CGFloat = 13
        static let bodyLineSpacing: CGFloat = 3
        static let contextFontSize: CGFloat = 10
        static let actionFontSize: CGFloat = 10
        static let touchTarget: CGFloat = 22
        #else
        static let bodyFontSize: CGFloat = 16
        static let bodyLineSpacing: CGFloat = 5
        static let contextFontSize: CGFloat = 12
        static let actionFontSize: CGFloat = 13
        static let touchTarget: CGFloat = 32
        #endif

        static let collapsedLineLimit = 8
        static let expansionThreshold = 800
    }

    private var canExpand: Bool {
        html.count > Metrics.expansionThreshold
    }

    private var maximumNumberOfLines: Int? {
        canExpand && !isExpanded ? Metrics.collapsedLineLimit : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let replyingTo {
                Text("Replying to \(replyingTo)")
                    .font(.system(size: Metrics.contextFontSize))
                    .foregroundStyle(.secondary)
            }

            #if os(iOS)
            TextKitCommentText(
                html: html,
                fontSize: Metrics.bodyFontSize,
                lineSpacing: Metrics.bodyLineSpacing,
                maximumNumberOfLines: maximumNumberOfLines
            )
            #else
            HTMLText(
                text: html,
                fontSize: Metrics.bodyFontSize,
                lineSpacing: Metrics.bodyLineSpacing
            )
            .lineLimit(maximumNumberOfLines)
            #endif

            if canExpand {
                Button(isExpanded ? "Show less" : "Read more") {
                    isExpanded.toggle()
                }
                .clickableCursor()
                .buttonStyle(.plain)
                .font(.system(size: Metrics.actionFontSize, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                #if os(iOS)
                .frame(minHeight: Metrics.touchTarget)
                .contentShape(Rectangle())
                #endif
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if os(iOS)
private extension NSAttributedString.Key {
    static let hackerNewsQuote = NSAttributedString.Key("HNReader.HackerNewsQuote")
}

/// TextKit 1 remains useful here because a custom layout manager can decorate
/// semantic ranges without inserting characters or breaking text selection.
private final class CommentLayoutManager: NSLayoutManager {
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)

        guard
            glyphsToShow.length > 0,
            let textStorage,
            let textContainer = textContainers.first
        else {
            return
        }

        let characterRange = characterRange(
            forGlyphRange: glyphsToShow,
            actualGlyphRange: nil
        )

        textStorage.enumerateAttribute(
            .hackerNewsQuote,
            in: characterRange
        ) { value, range, _ in
            guard value != nil else { return }

            let glyphRange = self.glyphRange(
                forCharacterRange: range,
                actualCharacterRange: nil
            )
            var bounds = self.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            guard !bounds.isNull, bounds.height > 0 else { return }

            bounds.origin.x += origin.x
            bounds.origin.y += origin.y

            let rule = CGRect(
                x: origin.x + 1,
                y: bounds.minY + 1,
                width: 3,
                height: max(3, bounds.height - 2)
            )

            UIColor.secondaryLabel.withAlphaComponent(0.7).setFill()
            UIBezierPath(roundedRect: rule, cornerRadius: 1.5).fill()
        }
    }
}

private struct TextKitCommentText: UIViewRepresentable {
    let html: String
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let maximumNumberOfLines: Int?

    struct Configuration: Equatable {
        let html: String
        let fontSize: CGFloat
        let lineSpacing: CGFloat
        let maximumNumberOfLines: Int?
    }

    final class Coordinator {
        var configuration: Configuration?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UITextView {
        let textStorage = NSTextStorage()
        let layoutManager = CommentLayoutManager()
        let textContainer = NSTextContainer(size: .zero)

        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        textContainer.lineFragmentPadding = 0

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let textView = UITextView(frame: .zero, textContainer: textContainer)
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.adjustsFontForContentSizeCategory = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let configuration = Configuration(
            html: html,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            maximumNumberOfLines: maximumNumberOfLines
        )

        guard context.coordinator.configuration != configuration else {
            return
        }

        context.coordinator.configuration = configuration

        let value = NSMutableAttributedString(
            attributedString: HTMLText.renderNative(html, fontSize: fontSize)
        )
        Self.markQuotes(in: value)
        Self.applyParagraphLayout(
            to: value,
            lineSpacing: lineSpacing,
            paragraphSpacing: lineSpacing + 4
        )

        if value.length > 0 {
            value.addAttribute(
                .foregroundColor,
                value: UIColor.label,
                range: NSRange(location: 0, length: value.length)
            )
        }

        textView.linkTextAttributes = [
            .foregroundColor: textView.tintColor ?? UIColor.link,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.textContainer.maximumNumberOfLines = maximumNumberOfLines ?? 0
        textView.textContainer.lineBreakMode = maximumNumberOfLines == nil
            ? .byWordWrapping
            : .byTruncatingTail
        textView.textStorage.setAttributedString(value)
        textView.invalidateIntrinsicContentSize()
        textView.setNeedsLayout()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width > 0 else {
            return nil
        }

        let size = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: ceil(size.height))
    }

    private static func markQuotes(in value: NSMutableAttributedString) {
        let ranges = paragraphRanges(in: value.string)

        for range in ranges.reversed() {
            let paragraph = (value.string as NSString).substring(with: range)
            let paragraphString = paragraph as NSString
            let firstVisible = paragraphString.rangeOfCharacter(
                from: .whitespacesAndNewlines.inverted
            )

            guard firstVisible.location != NSNotFound else { continue }

            let markerLocation = range.location + firstVisible.location
            guard (value.string as NSString).character(at: markerLocation) == 62 else {
                continue
            }

            if
                let font = value.attribute(.font, at: markerLocation, effectiveRange: nil) as? UIFont,
                font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace)
            {
                continue
            }

            var deletionLength = 1
            let nextLocation = markerLocation + 1

            if nextLocation < value.length {
                let nextCharacter = (value.string as NSString).character(at: nextLocation)
                if let scalar = UnicodeScalar(nextCharacter), CharacterSet.whitespaces.contains(scalar) {
                    deletionLength += 1
                }
            }

            value.deleteCharacters(
                in: NSRange(location: markerLocation, length: deletionLength)
            )

            let quoteRange = NSRange(
                location: range.location,
                length: max(0, range.length - deletionLength)
            )
            if quoteRange.length > 0 {
                value.addAttribute(.hackerNewsQuote, value: true, range: quoteRange)
            }
        }
    }

    private static func applyParagraphLayout(
        to value: NSMutableAttributedString,
        lineSpacing: CGFloat,
        paragraphSpacing: CGFloat
    ) {
        let ranges = paragraphRanges(in: value.string)

        for range in ranges {
            let existing = value.attribute(
                .paragraphStyle,
                at: range.location,
                effectiveRange: nil
            ) as? NSParagraphStyle
            let style = (existing?.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle()

            style.lineSpacing = lineSpacing
            style.paragraphSpacing = NSMaxRange(range) < value.length ? paragraphSpacing : 0

            if value.attribute(.hackerNewsQuote, at: range.location, effectiveRange: nil) != nil {
                style.firstLineHeadIndent = max(style.firstLineHeadIndent, 12)
                style.headIndent = max(style.headIndent, 12)
            }

            value.addAttribute(.paragraphStyle, value: style, range: range)
        }
    }

    private static func paragraphRanges(in string: String) -> [NSRange] {
        let value = string as NSString
        guard value.length > 0 else { return [] }

        var result: [NSRange] = []
        var location = 0

        while location < value.length {
            var start = 0
            var end = 0
            var contentsEnd = 0
            value.getParagraphStart(
                &start,
                end: &end,
                contentsEnd: &contentsEnd,
                for: NSRange(location: location, length: 0)
            )

            result.append(NSRange(location: start, length: end - start))
            location = max(end, location + 1)
        }

        return result
    }
}
#endif

#Preview("Comment text · Quotes", traits: .fixedLayout(width: 390, height: 430)) {
    CommentTextView(html: """
    <p>&gt; The best interfaces make the conversation easy to follow, even when the quoted passage wraps onto another line.</p>
    <p>I agree. A restrained rule is enough to distinguish the quoted material without turning it into a card.</p>
    <p>&gt; A second quote should receive its own marker.</p>
    <p>And paragraphs should have a little breathing room between them.</p>
    """)
    .padding(20)
}

#Preview("Comment text · HN formatting", traits: .fixedLayout(width: 390, height: 560)) {
    ScrollView {
        CommentTextView(html: #"""
        <p>Hacker News comments are mostly plain text, but they can contain <i>emphasis</i>, <b>strong text</b>, and <a href="https://news.ycombinator.com/formatdoc">links</a>.</p>
        <p>Paragraphs should keep their breathing room, while escaped characters such as <code>&lt;T&gt;</code> remain readable.</p>
        <pre><code>struct Story {
            let id: Int
            let title: String

            func summary() -&gt; String {
                "\(id): \(title)"
            }
        }</code></pre>
        <p>&gt; Quoted text receives a compact rule without losing selection.</p>
        """#)
        .padding(20)
    }
}

#Preview("Comment text · Code and links", traits: .fixedLayout(width: 640, height: 420)) {
    CommentTextView(html: """
    <p>I reduced the example to this:</p>
    <pre><code>let values = [1, 2, 3]
        .map { $0 * 2 }
        .filter { $0 &gt; 2 }

    print(values) // [4, 6]</code></pre>
    <p>The relevant behavior is described in <a href="https://developer.apple.com/documentation/swift">the Swift documentation</a>.</p>
    """)
    .padding(24)
}

#Preview("Comment text · Dark", traits: .fixedLayout(width: 390, height: 360)) {
    CommentTextView(
        html: """
        <p>&gt; Quotes should remain visible in dark mode.</p>
        <p>A dark-mode sample with <i>emphasis</i>, <code>inline code</code>, and a preformatted block:</p>
        <pre><code>if isReadable {
            render(comment)
        }</code></pre>
        """,
        replyingTo: "pg"
    )
    .padding(20)
    .preferredColorScheme(.dark)
}
