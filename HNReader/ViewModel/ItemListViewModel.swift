//
// Created by Mattia Righetti on 12/06/21.
//

import Combine
import SwiftUI
import HackerNews

class ItemListViewModel: ObservableObject {
    @Published var currentNewsSelection: HackerNews.API.Stories = .top {
        willSet {
            fetchStories(by: newValue)
        }
    }
    @Published var storiesIds: [Int] = []
    
    public func fetchStories(by category: HackerNews.API.Stories) {
        HackerNewsClient.shared.getStoriesId(by: category) { ids in
            DispatchQueue.main.async {
                self.storiesIds = ids
            }
        }
    }

    public func refreshStories() {
        fetchStories(by: currentNewsSelection)
    }
}
