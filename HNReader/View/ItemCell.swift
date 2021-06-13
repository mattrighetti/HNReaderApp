//
//  ItemCell.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI

struct ItemCell: View {
    var item: Item
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title!)
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
            
            if let host = item.urlHost {
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
                if let score = item.score {
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
                    Text("\(item.by ?? "anonymous")")
                        .foregroundColor(.yellow)
                        .fontWeight(.bold)
                        .redacted(reason: item.by != nil ? [] : .placeholder)
                    Text("•")
                        .padding(.horizontal, 1)
                    Text("\(item.timeStringRepresentation ?? "")")
                        .foregroundColor(.gray)
                }
                .font(.system(.callout, design: .rounded))
                
                Spacer()
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(10)
    }
}

struct ItemCell_Previews: PreviewProvider {
    static var previews: some View {
        let item = Item(id: 749324, deleted: false, type: .story, by: "mattrighetti", time: 1623530984811, text: "This is a pretty long title if I have to say", dead: false, parent: nil, poll: false, kids: nil, url: "https://www.hdblog.it", score: 42, title: "Ops, this was the intended title", parts: nil, descendants: nil)
        ItemCell(item: item)
    }
}
