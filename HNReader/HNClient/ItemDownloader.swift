//
// Created by Mattia Righetti on 13/06/21.
//

import Foundation

protocol ItemDownloader {
    func downloadItem(itemId: Int, completion: @escaping (Item?) -> Void)
}

class DefaultItemDownloader: ItemDownloader {
    func downloadItem(itemId: Int, completion: @escaping (Item?) -> ()) {
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
