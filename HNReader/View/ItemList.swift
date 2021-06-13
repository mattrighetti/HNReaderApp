//
//  ItemList.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI

struct ItemList: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = ItemListViewModel()
    @State private var itemLimitSelection: Int = 1
    private var itemLimitOptions: [Int] = [25, 50, 100]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(viewModel.stories, id: \.id) { item in
                    ItemCell(item: item)
                        .padding(.horizontal)
                }
                .redacted(reason: viewModel.fetching ? .placeholder : [])
            }
            .padding(.vertical)
        }
        .onAppear {
            if let selection = appState.newsSelection {
                viewModel.currentNewsSelection = selection
            } else {
                appState.sidebarSelection = .top
            }
        }
        .onReceive(appState.$newsSelection, perform: { newValue in
            if let newValue = newValue,
               viewModel.currentNewsSelection != newValue {
                viewModel.currentNewsSelection = newValue
            }
        })
        .toolbar {
            Picker("Limit", selection: $itemLimitSelection) {
                ForEach(itemLimitOptions.indices, id: \.self) { index in
                    Text("\(itemLimitOptions[index])").tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Button(action: viewModel.refreshStories) {
                Label("Refresh news", systemImage: "arrow.counterclockwise.circle")
            }
        }
        .navigationTitle("Hacker News")
    }
}

struct ItemList_Previews: PreviewProvider {
    static var previews: some View {
        ItemList()
    }
}
