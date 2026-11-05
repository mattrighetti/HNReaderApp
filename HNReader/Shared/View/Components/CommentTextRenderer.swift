import SwiftUI

#if os(iOS)
    import UIKit
#else
    import AppKit
#endif

extension NSAttributedString.Key {
    fileprivate static let hackerNewsQuote = NSAttributedString.Key("HNReader.HackerNewsQuote")
}

@MainActor
enum CommentTextFormatter {
    static func render(
        html: String,
        fontSize: CGFloat,
        lineSpacing: CGFloat
    ) async -> NSMutableAttributedString {
        let value = NSMutableAttributedString(
            attributedString: await HTMLText.renderNative(html, fontSize: fontSize)
        )
        markQuotes(in: value)
        applyParagraphLayout(
            to: value,
            lineSpacing: lineSpacing,
            paragraphSpacing: lineSpacing + 4
        )

        if value.length > 0 {
            #if os(iOS)
                let foregroundColor = UIColor.label
            #else
                let foregroundColor = NSColor.labelColor
            #endif

            value.addAttribute(
                .foregroundColor,
                value: foregroundColor,
                range: NSRange(location: 0, length: value.length)
            )
        }

        return value
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

            #if os(iOS)
                if let font = value.attribute(.font, at: markerLocation, effectiveRange: nil)
                    as? UIFont,
                    font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace)
                {
                    continue
                }
            #else
                if let font = value.attribute(.font, at: markerLocation, effectiveRange: nil)
                    as? NSFont,
                    NSFontManager.shared.traits(of: font).contains(.fixedPitchFontMask)
                {
                    continue
                }
            #endif

            var deletionLength = 1
            let nextLocation = markerLocation + 1

            if nextLocation < value.length {
                let nextCharacter = (value.string as NSString).character(at: nextLocation)
                if let scalar = UnicodeScalar(nextCharacter),
                    CharacterSet.whitespaces.contains(scalar)
                {
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
            let existing =
                value.attribute(
                    .paragraphStyle,
                    at: range.location,
                    effectiveRange: nil
                ) as? NSParagraphStyle
            let style =
                (existing?.mutableCopy() as? NSMutableParagraphStyle)
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

#if os(iOS)

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

    struct TextKitCommentText: UIViewRepresentable {
        let attributed: NSAttributedString
        let maximumNumberOfLines: Int?

        struct Configuration: Equatable {
            let attributed: NSAttributedString
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
                attributed: attributed,
                maximumNumberOfLines: maximumNumberOfLines
            )

            guard context.coordinator.configuration != configuration else {
                return
            }

            context.coordinator.configuration = configuration

            textView.linkTextAttributes = [
                .foregroundColor: textView.tintColor ?? UIColor.link,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ]
            textView.textContainer.maximumNumberOfLines = maximumNumberOfLines ?? 0
            textView.textContainer.lineBreakMode =
                maximumNumberOfLines == nil
                ? .byWordWrapping
                : .byTruncatingTail
            textView.textStorage.setAttributedString(attributed)
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

    }
#else
    /// AppKit uses the same TextKit formatter and quote attributes as iOS. The
    /// platform wrapper is intentionally thin so comment rendering cannot drift.
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

                NSColor.secondaryLabelColor.withAlphaComponent(0.7).setFill()
                NSBezierPath(roundedRect: rule, xRadius: 1.5, yRadius: 1.5).fill()
            }
        }
    }

    struct TextKitCommentText: NSViewRepresentable {
        let attributed: NSAttributedString
        let maximumNumberOfLines: Int?

        struct Configuration: Equatable {
            let attributed: NSAttributedString
            let maximumNumberOfLines: Int?
        }

        final class Coordinator {
            var configuration: Configuration?
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        func makeNSView(context: Context) -> NSTextView {
            let textStorage = NSTextStorage()
            let layoutManager = CommentLayoutManager()
            let textContainer = NSTextContainer(
                containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            )

            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
            textContainer.lineFragmentPadding = 0

            textStorage.addLayoutManager(layoutManager)
            layoutManager.addTextContainer(textContainer)

            let textView = NSTextView(frame: .zero, textContainer: textContainer)
            textView.drawsBackground = false
            textView.isEditable = false
            textView.isSelectable = true
            textView.isRichText = true
            textView.isVerticallyResizable = true
            textView.isHorizontallyResizable = false
            textView.textContainerInset = NSSize.zero
            textView.minSize = NSSize.zero
            textView.maxSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )

            return textView
        }

        func updateNSView(_ textView: NSTextView, context: Context) {
            let configuration = Configuration(
                attributed: attributed,
                maximumNumberOfLines: maximumNumberOfLines
            )

            guard context.coordinator.configuration != configuration else {
                return
            }

            context.coordinator.configuration = configuration

            textView.linkTextAttributes = [
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ]
            textView.textContainer?.maximumNumberOfLines = maximumNumberOfLines ?? 0
            textView.textContainer?.lineBreakMode =
                maximumNumberOfLines == nil
                ? .byWordWrapping
                : .byTruncatingTail
            textView.textStorage?.setAttributedString(attributed)
            textView.needsLayout = true
            textView.invalidateIntrinsicContentSize()
        }

        func sizeThatFits(
            _ proposal: ProposedViewSize,
            nsView textView: NSTextView,
            context: Context
        ) -> CGSize? {
            guard
                let width = proposal.width,
                width > 0,
                let textContainer = textView.textContainer,
                let layoutManager = textView.layoutManager
            else {
                return nil
            }

            textView.frame.size.width = width
            textContainer.containerSize = NSSize(
                width: width,
                height: CGFloat.greatestFiniteMagnitude
            )
            layoutManager.ensureLayout(for: textContainer)

            let used = layoutManager.usedRect(for: textContainer)
            return CGSize(
                width: width,
                height: ceil(used.height + textView.textContainerInset.height * 2)
            )
        }
    }
#endif
