import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Render HN's HTML as selectable, wrapping text with native links and theme colors.
struct HTMLText: View {
    let text: String
    var fontSize: CGFloat = 14
    var lineSpacing: CGFloat = 5

    @State private var attributed = AttributedString("")

    var body: some View {
        Text(attributed)
            .font(.system(size: fontSize))
            .foregroundStyle(.primary)
            .lineSpacing(lineSpacing)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: text) {
                attributed = Self.render(text, fontSize: fontSize)
            }
    }

    @MainActor static func render(_ html: String, fontSize: CGFloat = 14) -> AttributedString {
        AttributedString(renderNative(html, fontSize: fontSize))
    }

    @MainActor static func renderNative(_ html: String, fontSize: CGFloat = 14) -> NSAttributedString {
        guard
            let data = html.data(using: .utf8),
            let value = try? NSMutableAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
        else {
            return NSAttributedString(
                string: html.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        trimOuterWhitespace(from: value)

        let range = NSRange(location: 0, length: value.length)
        value.removeAttribute(.foregroundColor, range: range)
        value.removeAttribute(.backgroundColor, range: range)

        // Preserve emphasis, monospace, and links while using readable native sizing.
        value.enumerateAttribute(.font, in: range) { font, range, _ in
            #if os(macOS)
            guard let font = font as? NSFont else {
                return
            }

            let traits = NSFontManager.shared.traits(of: font)
            let targetSize = traits.contains(.fixedPitchFontMask)
                ? max(11, fontSize - 2)
                : fontSize
            let base = traits.contains(.fixedPitchFontMask)
                ? NSFont.monospacedSystemFont(ofSize: targetSize, weight: .regular)
                : NSFont.systemFont(ofSize: targetSize)

            value.addAttribute(
                .font,
                value: NSFontManager.shared.convert(base, toHaveTrait: traits),
                range: range
            )
            #else
            guard let font = font as? UIFont else {
                return
            }

            let descriptor = font.fontDescriptor
            let traits = descriptor.symbolicTraits
            let targetSize = traits.contains(.traitMonoSpace)
                ? max(11, fontSize - 2)
                : fontSize
            let base = traits.contains(.traitMonoSpace)
                ? UIFont.monospacedSystemFont(ofSize: targetSize, weight: .regular)
                : UIFont.systemFont(ofSize: targetSize)
            let styledDescriptor = base.fontDescriptor.withSymbolicTraits(traits) ?? base.fontDescriptor
            value.addAttribute(
                .font,
                value: UIFont(descriptor: styledDescriptor, size: targetSize),
                range: range
            )
            #endif
        }

        return value
    }

    private static func trimOuterWhitespace(from value: NSMutableAttributedString) {
        let string = value.string as NSString
        let visibleCharacters = CharacterSet.whitespacesAndNewlines.inverted
        let first = string.rangeOfCharacter(from: visibleCharacters)

        guard first.location != NSNotFound else {
            value.deleteCharacters(in: NSRange(location: 0, length: value.length))
            return
        }

        let last = string.rangeOfCharacter(from: visibleCharacters, options: .backwards)
        let contentEnd = NSMaxRange(last)

        if contentEnd < value.length {
            value.deleteCharacters(
                in: NSRange(location: contentEnd, length: value.length - contentEnd)
            )
        }

        if first.location > 0 {
            value.deleteCharacters(in: NSRange(location: 0, length: first.location))
        }
    }
}

#Preview("Rich text · Light", traits: .fixedLayout(width: 520, height: 280)) {
    HTMLText(text: """
    <p>Readable text with <b>emphasis</b>, <i>italics</i>, and
    <a href="https://news.ycombinator.com">a selectable link</a>.</p>
    <p>Paragraphs should wrap naturally in the discussion pane.</p>
    <pre><code>let message = "Stay curious."</code></pre>
    """)
    .padding(20)
    .preferredColorScheme(.light)
}

#Preview("Rich text · Dark", traits: .fixedLayout(width: 520, height: 240)) {
    HTMLText(
        text: "<p>A compact comment with <b>bold</b>, <i>italic</i>, and <code>monospace</code> text.</p>",
        fontSize: 13,
        lineSpacing: 3
    )
    .padding(20)
    .preferredColorScheme(.dark)
}
