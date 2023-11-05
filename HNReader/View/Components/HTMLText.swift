//
//  HTMLText.swift
//  HNReader
//
//  Created by Mattia Righetti on 13/06/21.
//

import SwiftUI

struct HTMLText: NSViewRepresentable {
    var text: String
    
    func makeNSView(context: Context) -> NSTextField {
        let text = NSTextField()
        text.isEditable = false
        if let attributedString = try? NSAttributedString(
            data: self.text.data(using: .utf8)!,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
        ) {
            text.attributedStringValue = attributedString
        }
        text.textColor = .white
        return text
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {}
}

#Preview {
    HTMLText(text: """
    string &lt;h1&gt;Krupal testing &lt;span style="font-weight:
    bold;"&gt;Customer WYWO&lt;/span&gt;&lt;/h1&gt;
    """)
}
