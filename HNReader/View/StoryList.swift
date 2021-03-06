//
//  ItemList.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI
import HackerNews
import OSLog

struct StoryList: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = ItemListViewModel()
    @State var itemLimitSelection: Int = 1
    @Binding var selectedItem: Int?
    var itemLimitOptions: [Int] = [25, 50, 100]
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(viewModel.storiesIds, id: \.self) { itemId in
                    NavigationLink(
                        destination: DetailStoryView(itemId: itemId),
                        label: {
                            ItemCell(itemId: itemId)
                        }
                    ).id(itemId)
                }
            }.onChange(of: appState.newsSelection, perform: { value in
                fetchItems(by: value)
                withAnimation {
                    proxy.scrollTo(viewModel.storiesIds.first)
                }
            })
        }
        .onAppear {
            viewModel.currentNewsSelection = appState.newsSelection
        }
        .toolbar {
            MaxItemPicker(enabled: false)
            Button(action: viewModel.refreshStories) {
                Label("Refresh news", systemImage: "arrow.counterclockwise.circle")
            }
        }
        .navigationTitle("Hacker News")
    }

    @ViewBuilder
    private func MaxItemPicker(enabled: Bool) -> some View {
        if enabled {
            Picker("Limit", selection: $itemLimitSelection) {
                ForEach(itemLimitOptions.indices, id: \.self) { index in
                    Text("\(itemLimitOptions[index])")
                            .tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        } else {
            EmptyView()
        }
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
        StoryList(selectedItem: .constant(nil))
            .environmentObject(AppState())
    }
}
