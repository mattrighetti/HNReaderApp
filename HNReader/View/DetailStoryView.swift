//
//  ItemView.swift
//  HNReader
//
//  Created by Mattia Righetti on 18/06/21.
//

import HackerNews
import HNScraper
import os
import SwiftUI

struct DetailStoryView: View {
    var itemId: Int

    @Environment(\.colorScheme) var colorScheme
    @State var item: Item?
    @State var fetching: Bool = false
    @State var comments: [HNComment]?
    @State var nextPage: Int = 1
    @State var showMore: Bool = false
    @State private var isHovering: Bool = false
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
                    set: { _ in }
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
        switch item?.type {
        case .story, .job:
            StorySection()
        default:
            Text("No view available for this element with id: \(itemId)")
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
                Text(text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 5)
            }

            LinkButtonsSection()
                .padding(.bottom, 5)

            HStack {
                if let score = item?.score {
                    Label(String(score), systemImage: "rosette")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.orange)
                }

                Link(destination: URL(string: "https://news.ycombinator.com/user?id=\(item?.by ?? "")")!, label: {
                    Label(item?.by ?? "unknown user", systemImage: "person")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(0.5)
                        .onHover(perform: updateHoverStatus)
                })

                Label(item?.relativeTime ?? "", systemImage: "clock")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(0.5)
            }
        }
    }

    @ViewBuilder
    func CommentsSection() -> some View {
        if let comments = comments {
            VStack(alignment: .leading) {
                ForEach(0 ..< comments.count) { i in
                    CommentCell(comment: comments[i], isOp: comments[i].username == item?.by)
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

    @ViewBuilder
    func LinkButtonsSection() -> some View {
        if item?.url != nil {
            HStack {
                Link(destination: item!.getUrl()) {
                    Text("Open article")
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.white, lineWidth: 2)
                        )
                }
                .foregroundColor(.white)
                .onHover(perform: updateHoverStatus)

                Link(destination: URL(string: "https://news.ycombinator.com/item?id=\(item!.id)")!) {
                    Text("Open on HN")
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.white, lineWidth: 2)
                        )
                }
                .foregroundColor(.white)
                .onHover(perform: updateHoverStatus)

                Spacer()
            }
        } else {
            HStack {
                Link(destination: URL(string: "https://news.ycombinator.com/item?id=\(item!.id)")!) {
                    Text("Open on HN")
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.white, lineWidth: 2)
                        )
                }
                .foregroundColor(.white)
                .onHover(perform: updateHoverStatus)

                Spacer()
            }
        }
    }

    private func fetchComments() {
        guard item!.kids != nil else { return }

        fetching.toggle()

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

    private func updateHoverStatus(hovering _: Bool) {
        isHovering.toggle()
        DispatchQueue.main.async {
            if self.isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct LoadingView<Content: View>: View {
    @Binding var condition: Bool
    let content: Content

    init(condition: Binding<Bool>, @ViewBuilder content: () -> Content) {
        _condition = condition
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
        DetailStoryView(itemId: 27_545_257)
    }
}
