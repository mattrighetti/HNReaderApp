//
//  ItemCell.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI
import HackerNews

struct ItemCell: View {
    var index: Int
    var itemId: Int
    let itemDownloader: ItemDownloader

    @State var item: Item?

    init(index: Int, itemId: Int) {
        self.index = index
        self.itemId = itemId
        itemDownloader = DefaultItemDownloader()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HostText()
            
            TitleView()
            
            HStack {
                ScoreText()
                
                Link(destination: URL(string: "https://news.ycombinator.com/user?id=\(item?.by ?? "")")!, label: {
                    Label(item?.by ?? "unknown user", systemImage: "person")
                        .font(.system(size: 10.0, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(0.5)
                })
                
                Spacer()
                
                CommentsCountText()
                
                Label(item?.relativeTime ?? "", systemImage: "clock")
                    .font(.system(size: 10.0, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(0.5)
            }
        }
        .padding(5)
        .onAppear {
            if item == nil {
                fetchItem()
            }
        }
    }

    @ViewBuilder
    private func TitleView() -> some View {
        if let item = item {
            Text(item.title ?? "No title")
                .font(.system(size: 15.0))
                .fontWeight(.bold)
        } else {
            Text("No title")
                .font(.system(size: 15.0))
                .fontWeight(.bold)
                .redacted(reason: .placeholder)
        }
    }

    @ViewBuilder
    private func HostText() -> some View {
        if let item = item {
            HStack {
                Text(String(index) + ".")
                    .font(.system(size: 10.0))
                    .fontWeight(.semibold)
                
                Link(destination: item.getUrl()) {
                    Text(item.urlHost ?? "")
                        .font(.system(size: 10.0, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
        } else {
            Text("No url")
                .font(.system(size: 10.0))
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .redacted(reason: .placeholder)
        }
    }

    @ViewBuilder
    private func ScoreText() -> some View {
        if let item = item {
            Text("\(item.score ?? 0)")
                .font(.system(size: 10.0))
                .foregroundColor(.orange)
                .fontWeight(.bold)
        } else {
            Text("0")
                .font(.system(size: 10.0))
                .foregroundColor(.orange)
                .fontWeight(.bold)
                .redacted(reason: .placeholder)
        }
    }
    
    @ViewBuilder
    private func CommentsCountText() -> some View {
        if let item = self.item {
            if let descendants = item.descendants {
                Label(title: {
                    Text(String(descendants))
                        .font(.system(size: 10.0))
                }, icon: {
                    Image(systemName: "message")
                        .foregroundColor(.white)
                })
                .opacity(0.5)
            }
        }
    }

    private func fetchItem() {
        let cacheKey = itemId
        if let cachedItem = ItemCache.shared.getItem(for: cacheKey) {
            self.item = cachedItem
        } else {
            itemDownloader.downloadItem(itemId: cacheKey, completion: { item in
                guard let item = item else { return }
                ItemCache.shared.cache(item, for: cacheKey)
                DispatchQueue.main.async {
                    self.item = item
                }
            })
        }
    }
}

struct OptionalText<Content: StringProtocol>: View {
    let content: Content?
    let other: String
    
    init(_ content: Content?, other: String) {
        self.content = content
        self.other = other
    }
    
    var body: some View {
        if let content = content {
            Text(content)
        } else {
            Text(other)
        }
    }
}

struct ItemCell_Previews: PreviewProvider {
    static var previews: some View {
        ItemCell(index: 10, itemId: 27492268)
    }
}
