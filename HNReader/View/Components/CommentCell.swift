//
//  CommentCell.swift
//  HNReader
//
//  Created by Mattia Righetti on 21/07/21.
//

import SwiftUI
import HackerNews

struct CommentCell: View {
    let comment: Comment
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(comment.by ?? "")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.yellow)
                .padding(.bottom, 3)
            
            HStack {
                Text(html: comment.text ?? "[deleted]")
                    .textSelection(.enabled)
                    .foregroundColor(.white)
                Spacer()
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
        .cornerRadius(10)
    }
}
