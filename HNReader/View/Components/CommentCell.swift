//
//  CommentCell.swift
//  HNReader
//
//  Created by Mattia Righetti on 21/07/21.
//

import HNScraper
import SwiftUI

struct CommentCell: View {
    let comment: HNComment
    var isOp: Bool

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
                Text(html: comment.text.replacingOccurrences(of: "<p>", with: "<br><br>"), size: 13)
                    .opacity(comment.showType == .downvoted ? 0.5 : 1.0)

                Spacer()
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(10)
    }
}
