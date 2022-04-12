//
//  +String.swift
//  HNReader
//
//  Created by Mattia Righetti on 21/07/21.
//

import Foundation

extension String {
    var htmlParsed: AttributedString {
        return AttributedString(htmlEncodedString: self) ?? "[deleted]"
    }
}

extension AttributedString {
    init?(htmlEncodedString: String) {
        guard let data = String(
            format:"<div style=\"font-family:'-apple-system','SF Regular';font-size: 15\">%@</div>",
            htmlEncodedString
                .replacingOccurrences(of: "<p>", with: "<br><br>")
                .replacingOccurrences(of: "</p>", with: "")
        ).data(using: .unicode) else { return nil }
        
        guard let nsAttrString = NSAttributedString(html: data, documentAttributes: nil) else { return nil }
        self.init(nsAttrString)
    }
}
