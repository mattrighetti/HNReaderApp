//
//  ItemList.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI
import OSLog

struct ItemList: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = ItemListViewModel()
    @State private var itemLimitSelection: Int = 1
    private var itemLimitOptions: [Int] = [25, 50, 100]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(viewModel.storiesIds, id: \.self) { itemId in
                    ItemCell(itemId: itemId)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            viewModel.currentNewsSelection = appState.newsSelection
        }
        .onChange(of: appState.newsSelection, perform: fetchItems)
        .toolbar {
            Picker("Limit", selection: $itemLimitSelection) {
                ForEach(itemLimitOptions.indices, id: \.self) { index in
                    Text("\(itemLimitOptions[index])")
                            .tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Button(action: viewModel.refreshStories) {
                Label("Refresh news", systemImage: "arrow.counterclockwise.circle")
            }
        }
        .navigationTitle("Hacker News")
    }

    private func fetchItems(by category: HackerNews.API.Stories) {
        if category != viewModel.currentNewsSelection {
            NSLog("changing category from \(viewModel.currentNewsSelection) to \(category)")
            viewModel.currentNewsSelection = category
        }
    }
}

struct ItemList_Previews: PreviewProvider {
    static var previews: some View {
        ItemList()
    }
}
