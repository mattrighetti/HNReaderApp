//
//  +String.swift
//  HNReader
//
//  Created by Mattia Righetti on 21/07/21.
//

import Foundation
import HTMLString

extension String {
    var htmlParsed: AttributedString {
        return AttributedString(htmlEncodedString: self) ?? "[deleted]"
    }
}

extension AttributedString {
    init?(htmlEncodedString: String) {
        let s = String(format:"<span style=\"font-family:'-apple-system','SF Mono';font-size: 15\">%@</span>", htmlEncodedString.removingHTMLEntities())
        guard let data = s.data(using: .utf8) else { return nil }
        guard let nsAttrString = NSAttributedString(html: data, documentAttributes: nil) else { return nil }
        self.init(nsAttrString)
    }
}
