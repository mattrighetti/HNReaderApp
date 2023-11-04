//
//  ItemCell.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI

struct ItemCell: View {
    var itemId: Int
    let itemDownloader: ItemDownloader

    @Environment(\.colorScheme) var colorScheme
    @State var item: Item?

    init(itemId: Int) {
        self.itemId = itemId
        itemDownloader = DefaultItemDownloader(itemId: itemId)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(item?.title ?? String(repeating: "-", count: 30))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .redactIfNull(item)

                Text(item?.urlHost ?? String(repeating: "-", count: 30))
                    .font(.callout)
                    .fontWeight(.light)
                    .foregroundColor(.white)
                    .redactIfNull(item)

                HStack {
                    Text(item?.scoreString ?? String(repeating: "-", count: 3))
                        .font(.callout)
                        .fontWeight(.bold)
                        .redactIfNull(item)

                    Text("Posted by \(item?.by ?? "?")")
                        .font(.callout)
                        .redactIfNull(item)

                    Text("\(item?.timeStringRepresentation ?? String(repeating: "-", count: 3))")
                        .font(.callout)
                        .redactIfNull(item)

                    Spacer()
                }
            }

            HStack {
                
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .foregroundStyle(Color.gray.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Label(title: {}, icon: {
                        Image(systemName: "bubble.left")
                    })
                    .padding()
                }
                .frame(width: 50, height: 50)
                .onHover { isHovered in
                    DispatchQueue.main.async {
                        if (isHovered) {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .onTapGesture {
                    if let item = item {
                        guard let url = URL(string: "https://news.ycombinator.com/item?id=\(item.id)") else { return }
                        NSWorkspace.shared.open(url)
                    }
                }
                
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .foregroundStyle(Color.gray.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Label(title: {}, icon: {
                        Image(systemName: "link")
                    })
                    .padding()
                }
                .frame(width: 50, height: 50)
                .onHover { isHovered in
                    DispatchQueue.main.async {
                        if (isHovered) {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .onTapGesture {
                    if let item = item {
                        guard let url = URL(string: item.url!) else { return }
                        NSWorkspace.shared.open(url)
                    }
                }
            }.padding(.leading)
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

    private func fetchItem() {
        let cacheKey = itemId
        if let cachedItem = ItemCache.shared.getItem(for: cacheKey) {
            self.item = cachedItem
        } else {
            itemDownloader.downloadItem(completion: { item in
                guard let item = item else { return }
                ItemCache.shared.cache(item, for: cacheKey)
                DispatchQueue.main.async {
                    self.item = item
                }
            })
        }
    }
}

struct ItemCell_Previews: PreviewProvider {
    static var previews: some View {
        ItemCell(itemId: 27492268)
    }
}
