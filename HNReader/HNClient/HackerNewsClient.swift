//
//  HackerNewsClient.swift
//  HNReader
//
//  Created by Mattia Righetti on 12/06/21.
//

import Foundation
import Combine
import Alamofire

/// HackerNews Client that exposes methods to get users, items and stories from https://news.ycombinator.com
class HackerNewsClient {
    public static let shared: HackerNewsClient = HackerNewsClient()
    private let session: URLSession = URLSession.shared
    private let decoder: JSONDecoder = JSONDecoder()
    private var subscriptions = Set<AnyCancellable>()
    
    /// Retrieves user  from HackerNews
    public func getUser(withId id: String) -> AnyPublisher<User, Error> {
        let url = URL(string: HackerNews.API.User.id(id).urlString)!
        return session
            .dataTaskPublisher(for: url)
            .retry(3)
            .map(\.data)
            .decode(type: User.self, decoder: decoder)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Retrieves item from HackerNews
    public func getItem(withId id: Int) -> AnyPublisher<Item, Error> {
        let url = URL(string: HackerNews.API.Item.id(id).urlString)!
        return session
            .dataTaskPublisher(for: url)
            .retry(3)
            .map(\.data)
            .decode(type: Item.self, decoder: decoder)
            .eraseToAnyPublisher()
    }
    
    /// Retrieves array of items from HackerNews
    ///
    /// You can specify which kind of stories you would like to retrieve:
    ///   - `top`
    ///   - `best`
    ///   - `new`
    public func getStoriesId(by api: HackerNews.API.Stories) -> AnyPublisher<[Int], Error> {
        let url = URL(string: api.urlString)!
        return session
            .dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [Int].self, decoder: decoder)
            .eraseToAnyPublisher()
    }

    public func getStories(withIds ids: [Int]) -> AnyPublisher<[Item], Error> {
        ids.publisher
            .flatMap(getItem)
            .collect()
            .eraseToAnyPublisher()
    }

    public func getStories(by category: HackerNews.API.Stories, limit: Int? = 50) -> AnyPublisher<[Item], Error> {
        getStoriesId(by: category)
            .flatMap(getStories)
            .eraseToAnyPublisher()
    }
    
    /// Recursively fetches comments and all its childrens
    public func getComments(commentsIds: [Int], completionHandler: @escaping (Bool, [Comment]) -> Void) {
        var returnComments : [Comment] = []
                
        let commentsGroup = DispatchGroup()
        for commentId in commentsIds {
            commentsGroup.enter()
            let itemUrl = HackerNews.API.Item.id(commentId).urlString
            AF.request(itemUrl).responseJSON { response in
                if let commentJSON = try! response.result.get() as? NSDictionary {
                    let commentObject = Comment.init(json: commentJSON)
                    commentObject.getComments(completionHandler: { (success) in
                        returnComments.append(commentObject)
                        commentsGroup.leave()
                    })
                } else {
                    commentsGroup.leave()
                }
            }
        }
        
        commentsGroup.notify(queue: .main) {
            returnComments.sort {a, b in
                commentsIds.firstIndex(of: a.id!)! < commentsIds.firstIndex(of: b.id!)!
            }
            
            completionHandler(true, returnComments)
        }
    }
}
