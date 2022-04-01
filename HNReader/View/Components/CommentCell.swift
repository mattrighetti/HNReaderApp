//
//  CommentCell.swift
//  HNReader
//
//  Created by Mattia Righetti on 21/07/21.
//

import SwiftUI
import HNScraper

struct CommentCell: View {
    let comment: HNComment
    var highlightBorder: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(comment.username ?? "")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.yellow)
                .padding(.bottom, 3)
            
            HStack {
                Text(comment.text.htmlParsed)
                    .opacity(comment.showType == .downvoted ? 0.5 : 1.0)
                Spacer()
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
        .modifier(HighlightBorder(highlight: highlightBorder))
        .cornerRadius(10)
    }
}

struct HighlightBorder: ViewModifier {
    var highlight: Bool
    
    func body(content: Content) -> some View {
        if highlight {
            content.overlay(RoundedRectangle(cornerRadius: 10).stroke(lineWidth: 2).foregroundColor(.yellow))
        } else {
            content
        }
    }
}
