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

    @State var item: Item?

    init(itemId: Int) {
        self.itemId = itemId
        itemDownloader = DefaultItemDownloader(itemId: itemId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item?.title ?? "No title")
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .redacted(reason: item?.title != nil ? [] : .placeholder)

            
            if let host = item?.urlHost {
                Text(host)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
//            if let text = item.text {
//                HTMLText(text: text)
//                    .font(.body)
//                    .lineLimit(3)
//                    .multilineTextAlignment(.leading)
//            }
            
            HStack {
                if let score = item?.score {
                    Text("\(score)")
                        .font(.system(.callout, design: .rounded))
                        .foregroundColor(.orange)
                        .fontWeight(.bold)
                }
                
                HStack {
                    Text("•")
                        .padding(.horizontal, 1)
                    Text("Posted by")
                        .foregroundColor(.gray)
                    Text("\(item?.by ?? "anonymous")")
                        .foregroundColor(.yellow)
                        .fontWeight(.bold)
                        .redacted(reason: item?.by != nil ? [] : .placeholder)
                    Text("•")
                        .padding(.horizontal, 1)
                    Text("\(item?.timeStringRepresentation ?? "")")
                        .foregroundColor(.gray)
                }
                .font(.system(.callout, design: .rounded))
                
                Spacer()
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(10)
        .onAppear {
            if item == nil {
                fetchItem()
            }
        }
        .onTapGesture {
            if let item = item {
                guard let url = URL(string: item.url!) else { return }
                NSWorkspace.shared.open(url)
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
