import SwiftUI

/// Render HN's HTML as selectable, wrapping text with native links and theme colors.
struct HTMLText: View {
    let text: String
    @State private var attributed = AttributedString("")

    var body: some View {
        Text(attributed)
            .font(.system(size: 14))
            .foregroundStyle(.primary)
            .lineSpacing(5)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: text) { attributed = Self.render(text) }
    }

    @MainActor static func render(_ html: String) -> AttributedString {
        guard let data = html.data(using: .utf8),
              let value = try? NSMutableAttributedString(
                data: data, options: [.documentType: NSAttributedString.DocumentType.html,
                                     .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil) else { return AttributedString(html) }
        let range = NSRange(location: 0, length: value.length)
        value.removeAttribute(.foregroundColor, range: range)
        value.removeAttribute(.backgroundColor, range: range)
        // Preserve emphasis, monospace, and links while using readable native sizing.
        value.enumerateAttribute(.font, in: range) { font, range, _ in
            guard let font = font as? NSFont else { return }
            let traits = NSFontManager.shared.traits(of: font)
            let base = traits.contains(.fixedPitchFontMask)
                ? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                : NSFont.systemFont(ofSize: 14)
            value.addAttribute(.font, value: NSFontManager.shared.convert(base, toHaveTrait: traits), range: range)
        }
        return AttributedString(value)
    }
}
