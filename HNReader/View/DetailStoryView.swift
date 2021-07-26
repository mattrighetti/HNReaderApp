//
//  ItemView.swift
//  HNReader
//
//  Created by Mattia Righetti on 18/06/21.
//

import SwiftUI
import HackerNews

struct DetailStoryView: View {
    var itemId: Int
    
    @Environment(\.colorScheme) var colorScheme
    @State var item: Item?
    @State var fetching: Bool = false
    @State var comments: [Comment]?
    @State var fetched: Int = 0
    @State var showMore: Bool = true
    var fetchStep: Int = 10
    
    init(itemId: Int) {
        self.itemId = itemId
    }
    
    var body: some View {
        ScrollView {
            ItemSection().padding()
            LoadingView(condition: .init(get: { self.fetching && self.comments == nil }, set: { _ in return })) {
                CommentsSection().padding()
            }
        }.onAppear {
            self.item = ItemCache.shared.getItem(for: self.itemId)
            fetchComments()
        }
    }
    
    @ViewBuilder
    func ItemSection() -> some View {
        switch self.item?.type {
        case .story, .job:
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
        if let comments = comments {
            VStack(alignment: .leading) {
                ForEach(comments, id: \.id) { comment in
                    CommentCell(comment: comment)
                        .padding(.leading, 50 * CGFloat(comment.indentLevel!))
                }
                if showMore {
                    Button("More...", action: {
                        fetchComments()
                    })
                    .padding(.top, 5)
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
    
    private func fetchComments() {
        if let commentsId = item?.kids {
            self.fetching.toggle()
            let subarray = commentsId.slice(from: fetched, next: 10)
            HackerNewsClient.shared.getComments(commentsIds: subarray.0) { _, comments in
                var flattenComments = [Any]()
                for comment in comments {
                    flattenComments += comment.flattenedComments() as! Array<Any>
                }
                
                DispatchQueue.main.async {
                    pushComments(comments: flattenComments.compactMap { $0 } as? [Comment], disableMoreButton: subarray.1)
                    self.fetching.toggle()
                }
            }
        }
    }
    
    private func pushComments(comments: [Comment]?, disableMoreButton: Bool) {
        guard comments != nil else { return }
        
        for comment in comments! {
            comment.text = String(htmlEncodedString: comment.text ?? "Empty comment")
        }
        
        if self.comments == nil {
            self.comments = [Comment]()
        }
        
        self.comments?.append(contentsOf: comments!)
        self.fetched += 10
        if disableMoreButton {
            self.showMore.toggle()
        }
    }
}

struct LoadingView<Content: View>: View {
    @Binding var condition: Bool
    let content: Content
    
    init(condition: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._condition = condition
        self.content = content()
    }
    
    var body: some View {
        if condition {
            LoadingCircle()
        } else {
            content
        }
    }
}

struct ItemView_Previews: PreviewProvider {
    static var previews: some View {
        DetailStoryView(itemId: 27545257)
    }
}
