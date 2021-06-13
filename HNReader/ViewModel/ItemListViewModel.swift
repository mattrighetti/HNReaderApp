//
// Created by Mattia Righetti on 12/06/21.
//

import Combine
import SwiftUI

class ItemListViewModel: ObservableObject {
    @Published var currentNewsSelection: HackerNews.API.Stories = .top {
        willSet {
            fetchStories(by: newValue)
        }
    }
    @Published var storiesIds:[Int] = []
    public var subscriptions = Set<AnyCancellable>()
    
    public func fetchStories(by category: HackerNews.API.Stories) {
        HackerNewsClient.shared.getStoriesId(by: currentNewsSelection, range: nil)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print(error)
                case .finished:
                    break
                }
            }, receiveValue: { [weak self] itemIds in
                self?.storiesIds = itemIds
            })
            .store(in: &subscriptions)
    }
    
    public func refreshStories() {
        fetchStories(by: currentNewsSelection)
    }
}
