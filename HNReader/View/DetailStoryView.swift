//
//  ItemView.swift
//  HNReader
//
//  Created by Mattia Righetti on 18/06/21.
//

import SwiftUI

struct DetailStoryView: View {
    var itemId: Int
    
    @Environment(\.colorScheme) var colorScheme
    @State var item: Item?
    @State var fetching: Bool = false
    @State var comments: [Comment]?
    
    init(itemId: Int) {
        self.itemId = itemId
    }
    
    var body: some View {
        ScrollView {
            ItemSection().padding()
            CommentsSection().padding()
        }.onAppear {
            self.item = ItemCache.shared.getItem(for: self.itemId)
            fetchComments()
        }
    }
    
    @ViewBuilder
    func ItemSection() -> some View {
        switch self.item?.type {
        case .story:
            StorySection()
        default:
            Text("No view available for this element with id: \(self.itemId)")
        }
    }
    
    @ViewBuilder
    func StorySection() -> some View {
        VStack(alignment: .leading) {
            Text(item?.title ?? "")
                .font(.largeTitle)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 5)
            
            HStack {
                Text("Posted by \(item?.by ?? "")")
                    .font(.system(.callout, design: .rounded))
                    .foregroundColor(.yellow)
                    .fontWeight(.bold)
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    func CommentsSection() -> some View {
        if fetching {
            LoadingCircle()
        } else {
            if let comments = comments {
                VStack(alignment: .leading) {
                    ForEach(comments, id: \.self) { comment in
                        CommentCell(comment: comment)
                            .padding(.leading, 50 * CGFloat(comment.indentLevel))
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Image("NoComments")
                        .resizable()
                        .frame(width: 400, height: 400, alignment: .center)
                    Spacer()
                }
            }
        }
    }
    
    private func fetchComments() {
        if let commentsId = item?.kids {
            self.fetching = true
            HackerNewsClient.shared.getComments(commentsIds: commentsId) { _, comments in
                var flattenComments = [Any]()
                for comment in comments {
                    flattenComments += comment.flattenedComments() as! Array<Any>
                }
                
                DispatchQueue.main.async {
                    self.comments = flattenComments.compactMap { $0 } as? [Comment]
                    if let comments = self.comments {
                        for comment in comments {
                            comment.text = String(htmlEncodedString: comment.text ?? "Empty comment")
                        }
                    }
                    self.fetching = false
                }
            }
        }
    }
}

struct ItemView_Previews: PreviewProvider {
    static var previews: some View {
        DetailStoryView(itemId: 27545257)
    }
}
