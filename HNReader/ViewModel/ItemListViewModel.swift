//
// Created by Mattia Righetti on 12/06/21.
//

import Combine
import SwiftUI

class ItemListViewModel: ObservableObject {
    @Published var fetching: Bool = false
    @Published var currentNewsSelection: HackerNews.API.Stories = .top {
        willSet {
            fetchStories(by: newValue)
        }
    }
    @Published var stories:[Item] = []
    public var subscriptions = Set<AnyCancellable>()
    
    public func fetchStories(by category: HackerNews.API.Stories) {
        fetching.toggle()
        HackerNewsClient.shared.getStories(by: category)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .failure(let error):
                    print(error)
                case .finished:
                    self?.fetching.toggle()
                }
            }, receiveValue: { [weak self] items in
                self?.stories = items.sorted(by: { $0.score! > $1.score! })
            })
            .store(in: &subscriptions)
    }
    
    public func refreshStories() {
        fetchStories(by: currentNewsSelection)
    }
}
