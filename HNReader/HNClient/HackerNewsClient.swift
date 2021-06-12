//
//  HackerNewsClient.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import Foundation
import Combine

class HackerNewsClient {
    public static let shared: HackerNewsClient = HackerNewsClient()
    private let session: URLSession = URLSession.shared
    private let decoder: JSONDecoder = JSONDecoder()
    
    /// Retrieves user  from HackerNews
    public func getUser(withId id: String) -> AnyPublisher<User, Error> {
        let url = URL(string: HackerNews.API.User.id(id).urlString)!
        return session
            .dataTaskPublisher(for: url)
            .retry(3)
            .tryMap { [unowned self] response in
                try decoder.decode(User.self, from: response.data)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Retrieves item from HackerNews
    public func getItem(withId id: Int) -> AnyPublisher<Item, Error> {
        let url = URL(string: HackerNews.API.Item.id(id).urlString)!
        return session
            .dataTaskPublisher(for: url)
            .retry(3)
            .tryMap { [unowned self] response in
                try decoder.decode(Item.self, from: response.data)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Retrieves array of items from HackerNews
    ///
    /// You can specify which kind of stories you would like to retrive:
    ///   - `top`
    ///   - `best`
    ///   - `new`
    public func getStories(by api: HackerNews.API.Stories) -> AnyPublisher<[Item], Error> {
        let url = URL(string: api.urlString)!
        return session
            .dataTaskPublisher(for: url)
            .retry(3)
            .tryMap { [unowned self] response in
                try decoder.decode([Item].self, from: response.data)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
