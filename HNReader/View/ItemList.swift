//
//  ItemList.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import SwiftUI

struct ItemList: View {
    @ObservedObject var viewModel = TopStoriesViewModel()
    
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
    }
}

struct ItemList_Previews: PreviewProvider {
    static var previews: some View {
        ItemList()
    }
}
