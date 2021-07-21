//
//  CommentCell.swift
//  HNReader
//
//  Created by Mattia Righetti on 21/07/21.
//

import SwiftUI

struct CommentCell: View {
    let comment: Comment
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(comment.by ?? "")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.yellow)
            
            HStack {
                Text(comment.text!)
                Spacer()
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
        .cornerRadius(10)
    }
}

struct CommentCell_Previews: PreviewProvider {
    static var previews: some View {
        CommentCell(comment: Comment())
    }
}
