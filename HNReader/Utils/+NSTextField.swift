//
//  +NSTextField.swift
//  HNReader
//
//  Created by Mattia Righetti on 21/07/21.
//

import AppKit

extension NSTextField {
    func setHTMLFromString(htmlText: String) {
        let modifiedFont = String(format:"<span style=\"font-family: '-apple-system', 'SF Mono'; font-size: \(self.font!.pointSize)\">%@</span>", htmlText)

        let attrStr = try! NSAttributedString(
            data: modifiedFont.data(using: .unicode, allowLossyConversion: true)!,
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding:String.Encoding.utf8.rawValue],
            documentAttributes: nil
        )

        self.stringValue = attrStr.string
    }
}
