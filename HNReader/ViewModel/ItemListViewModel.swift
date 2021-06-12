//
// Created by Mattia Righetti on 12/06/21.
//

import Combine
import Foundation

class ItemListViewModel: ObservableObject {
    @Published var fetching: Bool = false
    @Published var stories:[Item] = []
    private var subscriptions = Set<AnyCancellable>()

    init() {
        fetchStories()
    }
    
    private func fetchStories() {
        fetching.toggle()
        HackerNewsClient.shared.getTopStories()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                print("received completion")
            }, receiveValue: { [weak self] items in
                self?.stories = items.sorted(by: { $0.score! > $1.score! })
            })
            .store(in: &subscriptions)
        fetching.toggle()
    }
    
    public func refreshStories() {
        fetchStories()
    }
}
