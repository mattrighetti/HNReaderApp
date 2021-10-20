//
//  +Text.swift
//  HNReader
//
//  Created by Mattia Righetti on 10/20/21.
//

import SwiftUI

extension Text {
    init(html htmlString: String, raw: Bool = false, size: CGFloat? = 18.0, fontFamily: String = "-apple-system") { // optional document-wide font family
        
        let fullHTML: String
        if raw {
            fullHTML = htmlString
        } else {
            var sizeCss = ""
            if let size = size {
                sizeCss = "font-size: \(size)px;"
            }
            fullHTML = """
            <!doctype html>
            <html>
            <head>
            <style>
            body {
            font-family: \(fontFamily);
            \(sizeCss)
            }
            </style>
            </head>
            <body>
            \(htmlString)
            </body>
            </html>
            """
        }
        
        let attributedString: NSAttributedString
        if
            let data = fullHTML.data(using: .unicode),
            let attrString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
            attributedString = attrString
        } else {
            attributedString = NSAttributedString()
        }

        self.init(attributedString) // uses the NSAttributedString initializer
    }

    init(_ attributedString: NSAttributedString) {
        self.init("") // initial, empty Text

        // scan the attributed string for distinctly attributed regions
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { (attrs, range, _) in
            let string = attributedString.attributedSubstring(from: range).string
            var text = Text(string)
                .foregroundColor(.white)
                .font(.system(size: 15))

            // then, read applicable attributes and apply them to the Text

            if let font = attrs[.font] as? NSFont {
                // this takes care of the majority of formatting - text size, font family,
                // font weight, if it's italic, etc.
                text = text.font(.init(font))
            }

            if let color = attrs[.foregroundColor] as? NSColor {
                text = text.foregroundColor(Color(color))
            }

            if let kern = attrs[.kern] as? CGFloat {
                text = text.kerning(kern)
            }

            if #available(iOS 14.0, *) {
                if let tracking = attrs[.tracking] as? CGFloat {
                    text = text.tracking(tracking)
                }
            }

            if let strikethroughStyle = attrs[.strikethroughStyle] as? NSNumber,
               strikethroughStyle != 0 {
                if let strikethroughColor = (attrs[.strikethroughColor] as? NSColor) {
                    text = text.strikethrough(true, color: Color(strikethroughColor))
                } else {
                    text = text.strikethrough(true)
                }
            }

            if let underlineStyle = attrs[.underlineStyle] as? NSNumber,
               underlineStyle != 0 {
                if let underlineColor = (attrs[.underlineColor] as? NSColor) {
                    text = text.underline(true, color: Color(underlineColor))
                } else {
                    text = text.underline(true)
                }
            }

            if let baselineOffset = attrs[.baselineOffset] as? NSNumber {
                text = text.baselineOffset(CGFloat(baselineOffset.floatValue))
            }

            // append the newly styled subtext to the rest of the text
            self = self + text
        }
    }
}
