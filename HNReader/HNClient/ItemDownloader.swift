//
// Created by Mattia Righetti on 13/06/21.
//

import Foundation

protocol ItemDownloader {
    var cacheKey: Int { get }
    func downloadItem(completion: @escaping (Item?) -> Void)
}

class DefaultItemDownloader: ItemDownloader {
    let itemId: Int
    var cacheKey: Int {
        itemId
    }

    init(itemId: Int) {
        self.itemId = itemId
    }

    func downloadItem(completion: @escaping (Item?) -> ()) {
        guard let url = URL(string: HackerNews.API.Item.id(itemId).urlString) else { return }
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let data = data {
                var item: Item
                do {
                    item = try JSONDecoder().decode(Item.self, from: data)
                    completion(item)
                } catch {
                    print("encountered error while downloading item")
                    completion(nil)
                }
            }
        }
        task.resume()
    }
}
