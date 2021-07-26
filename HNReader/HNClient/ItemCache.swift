//
// Created by Mattia Righetti on 13/06/21.
//

import Foundation
import HackerNews

class StructWrapper<T>: NSObject {
    let value: T

    init(_ _struct: T) {
        value = _struct
    }
}


class ItemCache: NSCache<NSString, StructWrapper<Item>> {
    static let shared = ItemCache()

    func cache(_ item: Item, for key: Int) {
        let keyString = NSString(format: "%d", key)
        let itemWrapper = StructWrapper(item)
        self.setObject(itemWrapper, forKey: keyString)
    }

    func getItem(for key: Int) -> Item? {
        let keyString = NSString(format: "%d", key)
        let itemWrapper = self.object(forKey: keyString)
        return itemWrapper?.value
    }
}
