import XCTest
import UIKit
@testable import HNReader

@MainActor
final class CommentImageRendererTests: XCTestCase {
    private let snapshot = CommentImageSnapshot(
        id: 8863, author: "dhouston",
        html: """
            <p>The best tools make sharing an idea feel effortless.</p>
            <p>&gt; Make something people want.</p>
            <p>Keep <i>the context</i>, credit the author, and link to the
            <a href="https://news.ycombinator.com">conversation</a>. &amp; enjoy it 👋</p>
            <pre><code>let idea = "Share the conversation"</code></pre>
            """
    )

    func testEveryPaletteProducesBoundedPNGAndPreservesText() async throws {
        let formatted = try await CommentImageRenderer.format(snapshot)
        for palette in CommentImageStyle.Palette.allCases {
            let output = try CommentImageRenderer.render(
                snapshot: snapshot, formatted: formatted, style: CommentImageStyle(palette: palette))
            let image = try XCTUnwrap(UIImage(data: output.png)?.cgImage)
            XCTAssertEqual(image.width, 1080)
            XCTAssertLessThanOrEqual(image.height, 4096)
            XCTAssertEqual(output.text, formatted.string)
            XCTAssertTrue(output.text.contains("& enjoy it 👋"))
            let attachment = XCTAttachment(data: output.png, uniformTypeIdentifier: "public.png")
            attachment.name = palette.rawValue
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testFormattingPreservesLinksQuotesAndFontTraits() async throws {
        let formatted = try await CommentImageRenderer.format(snapshot)
        var hasLink = false
        var hasQuote = false
        var hasItalic = false
        var hasCode = false
        formatted.enumerateAttributes(in: NSRange(location: 0, length: formatted.length)) { attrs, _, _ in
            hasLink = hasLink || attrs[.link] != nil
            hasQuote = hasQuote || attrs[.hackerNewsQuote] != nil
            if let font = attrs[.font] as? UIFont {
                hasItalic = hasItalic || font.fontDescriptor.symbolicTraits.contains(.traitItalic)
                hasCode = hasCode || font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace)
            }
        }
        XCTAssertTrue(hasLink)
        XCTAssertTrue(hasQuote)
        XCTAssertTrue(hasItalic)
        XCTAssertTrue(hasCode)
    }

    func testBlankHTMLCannotProduceImage() async throws {
        for html in ["", "  ", "<p> &nbsp; </p>"] {
            do {
                _ = try await CommentImageRenderer.format(CommentImageSnapshot(id: 1, author: "reader", html: html))
                XCTFail("Expected an empty-content failure")
            } catch CommentImageRenderer.Failure.empty {
                // Expected after HTML formatting, including entity-only content.
            }
        }
    }

    func testMenuExcludesUnavailableAndEmptyComments() throws {
        let examples: [(String, Bool)] = [
            (#"{"id":1,"text":"<p>A comment.</p>"}"#, true),
            (#"{"id":1,"text":"<p>&lt;code&gt;</p>"}"#, true),
            (#"{"id":1}"#, false),
            (#"{"id":1,"text":"<p> &nbsp; &#160; &#xA0; </p>"}"#, false),
            (#"{"id":1,"deleted":true,"text":"Removed"}"#, false),
            (#"{"id":1,"dead":true,"text":"Removed"}"#, false),
        ]
        for (json, expected) in examples {
            let item = try JSONDecoder().decode(Item.self, from: Data(json.utf8))
            XCTAssertEqual(CommentImageSnapshot.canExport(item), expected)
        }
    }

    func testOverflowFailsInsteadOfTruncating() async throws {
        let long = CommentImageSnapshot(
            id: 1, author: "reader", html: String(repeating: "<p>A longer conversation.</p>", count: 100))
        let formatted = try await CommentImageRenderer.format(long)
        XCTAssertThrowsError(try CommentImageRenderer.render(snapshot: long, formatted: formatted, style: .init())) {
            guard case CommentImageRenderer.Failure.tooLong = $0 else {
                return XCTFail("Expected overflow, got \($0)")
            }
        }
    }

    func testWatermarkTogglePreservesCommentAndChangesHeight() async throws {
        let formatted = try await CommentImageRenderer.format(snapshot)
        let branded = try CommentImageRenderer.render(snapshot: snapshot, formatted: formatted, style: .init())
        let unbranded = try CommentImageRenderer.render(
            snapshot: snapshot, formatted: formatted, style: CommentImageStyle(watermark: false))
        XCTAssertEqual(branded.text, unbranded.text)
        XCTAssertGreaterThan(branded.image.size.height, unbranded.image.size.height)
    }

    func testHiddenUsernameDoesNotAppearInImage() async throws {
        let formatted = try await CommentImageRenderer.format(snapshot)
        let otherAuthor = CommentImageSnapshot(id: snapshot.id, author: "another_author", html: snapshot.html)
        let style = CommentImageStyle(includeUsername: false)
        let first = try CommentImageRenderer.render(snapshot: snapshot, formatted: formatted, style: style)
        let second = try CommentImageRenderer.render(snapshot: otherAuthor, formatted: formatted, style: style)
        XCTAssertEqual(first.png, second.png)
        let identified = try CommentImageRenderer.render(snapshot: snapshot, formatted: formatted, style: .init())
        XCTAssertLessThan(first.image.size.height, identified.image.size.height)
    }

    func testArticleTitleIsOptionalAndWrapsWithoutChangingComment() async throws {
        let titled = CommentImageSnapshot(
            id: snapshot.id, author: snapshot.author, html: snapshot.html,
            articleTitle: "My YC app: Dropbox — Throw away your USB drive")
        let formatted = try await CommentImageRenderer.format(titled)
        let plain = try CommentImageRenderer.render(snapshot: snapshot, formatted: formatted, style: .init())
        let titleOff = try CommentImageRenderer.render(snapshot: titled, formatted: formatted, style: .init())
        XCTAssertEqual(plain.png, titleOff.png)
        let titleOn = try CommentImageRenderer.render(
            snapshot: titled, formatted: formatted, style: CommentImageStyle(includeArticleTitle: true))
        XCTAssertEqual(titleOn.text, plain.text)
        XCTAssertGreaterThan(titleOn.image.size.height, plain.image.size.height)
        let attachment = XCTAttachment(data: titleOn.png, uniformTypeIdentifier: "public.png")
        attachment.name = "Article title included"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMissingTitleRequiresContextOnlyWhenEnabled() async throws {
        let formatted = try await CommentImageRenderer.format(snapshot)
        let style = CommentImageStyle(includeArticleTitle: true)
        XCTAssertThrowsError(try CommentImageRenderer.render(snapshot: snapshot, formatted: formatted, style: style)) {
            XCTAssertEqual($0 as? CommentImageRenderer.Failure, .articleTitleUnavailable)
        }
        let resolved = try CommentImageRenderer.render(
            snapshot: snapshot, formatted: formatted, style: style, articleTitle: "Loaded story title")
        XCTAssertEqual(resolved.text, formatted.string)
        XCTAssertNoThrow(try CommentImageRenderer.render(snapshot: snapshot, formatted: formatted, style: .init()))
    }

    func testTitleParticipatesInImageHeightLimit() async throws {
        let formatted = try await CommentImageRenderer.format(snapshot)
        XCTAssertThrowsError(try CommentImageRenderer.render(
            snapshot: snapshot, formatted: formatted, style: CommentImageStyle(includeArticleTitle: true),
            articleTitle: String(repeating: "A long article title that wraps across lines. ", count: 100))) {
            XCTAssertEqual($0 as? CommentImageRenderer.Failure, .tooLong)
        }
    }

    func testLongCodeURLsAndMultilingualTextWrap() async throws {
        let snapshot = CommentImageSnapshot(id: 123, author: String(repeating: "reader", count: 12), html: """
            <p>日本語のコメント。مرحبا بالعالم 👨‍👩‍👧‍👦</p>
            <p>https://example.com/\(String(repeating: "longpath", count: 30))</p>
            <pre><code>\(String(repeating: "long_identifier_", count: 25))</code></pre>
            """)
        let formatted = try await CommentImageRenderer.format(snapshot)
        let output = try CommentImageRenderer.render(snapshot: snapshot, formatted: formatted, style: .init())
        XCTAssertEqual(output.text, formatted.string)
        let attachment = XCTAttachment(data: output.png, uniformTypeIdentifier: "public.png")
        attachment.name = "Wrapping and scripts"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSharedFileContainsPreviewPNGAndIsRemovedAfterSession() async throws {
        let formatted = try await CommentImageRenderer.format(snapshot)
        let output = try CommentImageRenderer.render(snapshot: snapshot, formatted: formatted, style: .init())
        var file: CommentImageShareFile? = try CommentImageShareFile(png: output.png, commentID: snapshot.id)
        let url = try XCTUnwrap(file?.url)
        XCTAssertEqual(try Data(contentsOf: url), output.png)
        file = nil
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testPaletteInkContrast() {
        func luminance(_ color: UIColor) -> CGFloat {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            func linear(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        for palette in CommentImageStyle.Palette.allCases {
            let background = luminance(palette.background), foreground = luminance(palette.ink)
            XCTAssertGreaterThanOrEqual((max(background, foreground) + 0.05) / (min(background, foreground) + 0.05), 4.5)
        }
    }
}
