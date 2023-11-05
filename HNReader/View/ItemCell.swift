//
//  ItemCell.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI

func nullableString(_ s: String?) -> String {
    guard let s = s else { return "" }
    return s
}

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
                    .font(.custom("IBMPlexSerif-Bold", size: 17))
                    .redactIfNull(item)

                if let url = item?.urlHost {
                    Text(url)
                        .font(.custom("IBMPlexSerif-Light", size: 12))
                        .redactIfNull(item)
                }

                HStack {
                    Text(nullableString(item?.scoreString))
                        .font(.custom("IBMPlexSerif-SemiBold", size: 12))
                        .redactIfNull(item)

                    Text("Posted by \(nullableString(item?.by))")
                        .font(.custom("IBMPlexSerif-Regular", size: 12))
                        .redactIfNull(item)

                    Text("\(nullableString(item?.timeStringRepresentation))")
                        .font(.custom("IBMPlexSerif-Regular", size: 12))
                        .redactIfNull(item)

                    Spacer()
                }
            }

            HStack {
                BgButton(icon: "bubble.left", minSize: CGSize(width: 50, height: 50), onHover: { isHovered in
                    DispatchQueue.main.async {
                        if (isHovered) {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }, action: {
                    if let item = item {
                        guard let url = URL(string: "https://news.ycombinator.com/item?id=\(item.id)") else { return }
                        NSWorkspace.shared.open(url)
                    }
                })

                BgButton(icon: "arrow.up.right", disabled: item?.url == nil, minSize: CGSize(width: 50, height: 50), onHover: { isHovered in
                    DispatchQueue.main.async {
                        if (isHovered) {
                            if item?.url == nil {
                                NSCursor.operationNotAllowed.push()
                            } else {
                                NSCursor.pointingHand.push()
                            }
                        } else {
                            NSCursor.pop()
                        }
                    }
                }, action: {
                    guard let url = item?.url, let url = URL(string: url) else { return }
                    NSWorkspace.shared.open(url)
                })
            }
            .padding(.leading)
        }
        .padding()
        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
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

#Preview {
    ItemCell(itemId: 27492268)
}
