import SwiftUI

#if os(iOS)
    import UIKit
#else
    import AppKit
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
    @State private var attributed = NSAttributedString(string: "")

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

            TextKitCommentText(
                attributed: attributed,
                maximumNumberOfLines: maximumNumberOfLines
            )

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
        .task(id: html) {
            guard !Task.isCancelled else { return }
            let rendered = await CommentTextFormatter.render(
                html: html,
                fontSize: Metrics.bodyFontSize,
                lineSpacing: Metrics.bodyLineSpacing
            )
            guard !Task.isCancelled else { return }
            attributed = rendered
        }
    }
}

#Preview("Comment text · Quotes", traits: .fixedLayout(width: 390, height: 430)) {
    CommentTextView(
        html: """
            <p>&gt; The best interfaces make the conversation easy to follow, even when the quoted passage wraps onto another line.</p>
            <p>I agree. A restrained rule is enough to distinguish the quoted material without turning it into a card.</p>
            <p>&gt; A second quote should receive its own marker.</p>
            <p>And paragraphs should have a little breathing room between them.</p>
            """
    )
    .padding(20)
}

#Preview("Comment text · HN formatting", traits: .fixedLayout(width: 390, height: 560)) {
    ScrollView {
        CommentTextView(
            html: #"""
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
                """#
        )
        .padding(20)
    }
}

#Preview("Comment text · Code and links", traits: .fixedLayout(width: 640, height: 420)) {
    CommentTextView(
        html: """
            <p>I reduced the example to this:</p>
            <pre><code>let values = [1, 2, 3]
                .map { $0 * 2 }
                .filter { $0 &gt; 2 }

            print(values) // [4, 6]</code></pre>
            <p>The relevant behavior is described in <a href="https://developer.apple.com/documentation/swift">the Swift documentation</a>.</p>
            """
    )
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
