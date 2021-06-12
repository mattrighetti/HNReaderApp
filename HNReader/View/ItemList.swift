//
//  ItemList.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI

struct ItemList: View {
    @ObservedObject var viewModel = ItemListViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(viewModel.stories, id: \.id) { item in
                    ItemCell(item: item)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .toolbar {
            Button(action: viewModel.refreshStories) {
                Label("Refresh news", systemImage: "arrow.counterclockwise.circle")
            }
        }
        .navigationTitle("Hacker News")
        .navigationSubtitle("by mattrighetti")
    }
}

struct ItemList_Previews: PreviewProvider {
    static var previews: some View {
        ItemList()
    }
}
