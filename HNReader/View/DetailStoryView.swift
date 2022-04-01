//
//  ItemView.swift
//  HNReader
//
//  Created by Mattia Righetti on 18/06/21.
//

import os
import SwiftUI
import HackerNews
import HNScraper

struct DetailStoryView: View {
    var itemId: Int
    
    @Environment(\.colorScheme) var colorScheme
    @State var item: Item?
    @State var fetching: Bool = false
    @State var comments: [HNComment]?
    @State var nextPage: Int = 1
    @State var showMore: Bool = false
    let dispatchQueue = DispatchQueue(label: "CommentScrapingThreadQueue", qos: .background)
    
    init(itemId: Int) {
        self.itemId = itemId
    }
    
    var body: some View {
        ScrollView {
            ItemSection()
                .padding([.top, .leading, .trailing])
                .padding(.bottom, 3)
            
            LoadingView(
                condition: .init(
                    get: { self.fetching && self.comments == nil },
                    set: { _ in return }
                )
            ) {
                CommentsSection()
                    .padding()
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
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 5)
            
            if let text = item?.text {
                Text(text.htmlParsed)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 5)
            }
            
            HStack {
                Text("Posted by ")
                    .font(.system(.callout, design: .rounded))
                    .foregroundColor(.gray)
                
                Text(item?.by ?? "")
                    .font(.system(.callout, design: .rounded))
                    .foregroundColor(.yellow)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            HStack {
                Button("Open on HN") {
                    NSWorkspace.shared.open(URL(string: "https://news.ycombinator.com/item?id=\(item!.id)")!)
                }
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    func CommentsSection() -> some View {
        if let comments = comments {
            VStack(alignment: .leading) {
                ForEach(0..<comments.count) { i in
                    CommentCell(comment: comments[i], highlightBorder: comments[i].username == item?.by)
                        .padding(.leading, 20 * CGFloat(comments[i].level))
                }
                
                if showMore {
                    Button("More...") {
                        fetchComments()
                    }
                    .padding(.top, 5)
                }
            }
        } else {
            VStack {
                Spacer()
                Image("SpeechBubble")
                    .resizable()
                    .frame(width: 200, height: 200, alignment: .center)
                Text("No comments here...")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                Spacer()
            }
        }
    }
    
    private func fetchComments() {
        guard item!.kids != nil else { return }
        
        self.fetching.toggle()
        
        dispatchQueue.async {
            HNScraper.shared.getPost(ById: String(item!.id), buildHierarchy: false) { post, comments, error in
                guard error == nil else { return }
                
                if post?.type == .defaultType {
                    self.comments = comments
                } else {
                    for comment in comments {
                        comment.level -= 1
                    }
                    self.comments = Array(comments[1 ..< comments.count - 1])
                }
            }
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
            ProgressView()
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
