//
// Created by Mattia Righetti on 13/06/21.
//

import Foundation
import HackerNews

protocol ItemDownloader {
    func downloadItem(itemId: Int, completion: @escaping (Item?) -> Void)
}

class DefaultItemDownloader: ItemDownloader {
    func downloadItem(itemId: Int, completion: @escaping (Item?) -> Void) {
        HackerNewsFirebaseClient.shared.getItem(withId: itemId, completionHandler: completion)
    }
}
