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
                .padding()
            
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
                .font(.largeTitle)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 5)
            
            if let text = item?.text {
                Text(html: text)
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
        }
    }
    
    @ViewBuilder
    func CommentsSection() -> some View {
        if let comments = comments {
            VStack(alignment: .leading) {
                ForEach(comments, id: \.id) { comment in
                    CommentCell(comment: comment)
                        .padding(.leading, 20 * CGFloat(comment.level))
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
        guard item!.kids != nil else { return }
        self.fetching.toggle()
        dispatchQueue.async {
            HNScraper.shared.getPost(ById: "\(item!.id)", buildHierarchy: false) { post, comments, error in
                guard error == nil else { return }
                self.comments = comments
            }
        }
    }
    
    private func parseToNSAttributedString(string: String) -> NSAttributedString? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }

        return attributedString
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
