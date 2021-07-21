//
//  HTMLText.swift
//  HNReader
//
//  Created by Mattia Righetti on 21/07/21.
//

import SwiftUI

struct HTMLText: NSViewRepresentable {
    let text: String
    
    func updateNSView(_ nsView: NSViewType, context: Context) {}
    
    func makeNSView(context: Context) -> some NSView {
        let label = NSTextField()
        label.setHTMLFromString(htmlText: text)
        label.backgroundColor = .clear
        label.isBezeled = false
        label.textColor = .white
        label.isEditable = false
        label.textColor = NSColor.init(cgColor: Color.white.opacity(0.7).cgColor!)
        label.font = .systemFont(ofSize: 15)
        label.sizeToFit()
        return label
    }
}

struct HTMLText_Previews: PreviewProvider {
    static var previews: some View {
        HTMLText(text: "<b>Bold</b>")
    }
}
