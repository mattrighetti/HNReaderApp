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
    var isOp: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                if isOp {
                    Text("OP")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.orange)
                        .clipShape(Circle())
                }
                
                Label(comment.username ?? "", systemImage: "person")
                    .font(.system(size: 10.0, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(0.5)
                
                Label(comment.created ?? "", systemImage: "clock")
                    .font(.system(size: 10.0, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(0.5)
            }
            .padding(.bottom, 3)
            
            HStack {
                Text(comment.text.htmlParsed)
                    .opacity(comment.showType == .downvoted ? 0.5 : 1.0)
                
                Spacer()
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
        .cornerRadius(10)
    }
}
