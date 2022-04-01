//
//  ItemCell.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI
import HackerNews

struct ItemCell: View {
    var itemId: Int
    let itemDownloader: ItemDownloader

    @Environment(\.colorScheme) var colorScheme
    @State var item: Item?
    @State private var isHovering: Bool = false

    init(itemId: Int) {
        self.itemId = itemId
        itemDownloader = DefaultItemDownloader()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            TitleView()
                .onHover(perform: updateHoverStatus)
                .onTapGesture {
                    if let item = item {
                        if let url = item.url {
                            NSWorkspace.shared.open(URL(string: url)!)
                        } else {
                            // TODO apply this logic directly in struct
                            NSWorkspace.shared.open(URL(string: "https://news.ycombinator.com/item?id=" + String(describing: itemId))!)
                        }
                    }
                }
            
            HostText()
            
            HStack {
                ScoreText()
                
                Text(item?.by ?? "unknown user")
                    .foregroundColor(.yellow)
                    .font(.system(size: 10.0, weight: .bold, design: .rounded))
                
                CommentsCountText()
                Spacer()
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
        .cornerRadius(10)
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
//                AsyncImage(url: URL(string: "https://\(item.urlHost ?? "")/favicon.ico")!, scale: 1) { image in
//                    image.resizable().aspectRatio(contentMode: .fit).frame(width: 15, height: 15)
//                } placeholder: {
//                    Color.gray.opacity(0.3)
//                }
//                .frame(width: 15, height: 15)
                
                Text(item.urlHost ?? "")
                    .font(.system(size: 10.0))
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
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
                Text("\(descendants) comments")
                    .font(.system(size: 10.0))
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
    
    private func updateHoverStatus(hovering: Bool) -> Void {
        self.isHovering.toggle()
        DispatchQueue.main.async {
            if (self.isHovering) {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
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
        ItemCell(itemId: 27492268)
    }
}
