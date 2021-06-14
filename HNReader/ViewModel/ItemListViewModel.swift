//
// Created by Mattia Righetti on 12/06/21.
//

import Combine
import SwiftUI
import OSLog

class ItemListViewModel: ObservableObject {
    @Published var currentNewsSelection: HackerNews.API.Stories = .top {
        willSet {
            fetchStories(by: newValue)
        }
    }
    @Published var storiesIds: [Int] = []
    public var subscriptions = Set<AnyCancellable>()
    
    public func fetchStories(by category: HackerNews.API.Stories) {
        HackerNewsClient.shared.getStoriesId(by: category)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    NSLog("encountered error while completing fetch task: \(error)")
                case .finished:
                    break
                }
            }, receiveValue: { [unowned self] itemIds in
                storiesIds = itemIds
            })
            .store(in: &subscriptions)
    }

    public func refreshStories() {
        fetchStories(by: currentNewsSelection)
    }
}
