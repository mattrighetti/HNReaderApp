import Foundation

/// Thread-safe, memory-pressure-aware cache shared by feed rows and discussions.
/// NSNumber preserves the full story ID; NSCache can evict entries at any time.
final class ItemCache: @unchecked Sendable {
    private final class Entry: NSObject {
        let item: Item
        let expiresAt: Date

        init(item: Item, expiresAt: Date) {
            self.item = item
            self.expiresAt = expiresAt
        }
    }

    private let storage = NSCache<NSNumber, Entry>()
    private let lock = NSLock()
    private var requests: [Int: UUID] = [:]
    private let lifetime: TimeInterval
    private let now: @Sendable () -> Date

    init(
        lifetime: TimeInterval = 120,
        countLimit: Int = 1000,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.lifetime = lifetime
        self.now = now
        storage.countLimit = countLimit
        storage.name = "Hacker News items"
    }

    func item(id: Int) -> Item? {
        let key = NSNumber(value: id)

        guard let entry = storage.object(forKey: key) else {
            return nil
        }

        guard entry.expiresAt > now() else {
            return nil
        }

        return entry.item
    }

    func insert(_ item: Item) {
        lock.withLock {
            requests.removeValue(forKey: item.id)
            store(item)
        }
    }

    func beginRequest(id: Int) -> UUID {
        lock.withLock {
            let request = UUID()
            requests[id] = request

            return request
        }
    }

    func finishRequest(id: Int, request: UUID, item: Item?) {
        lock.withLock {
            guard requests[id] == request else {
                return
            }

            requests.removeValue(forKey: id)

            if let item {
                store(item)
            } else {
                storage.removeObject(forKey: NSNumber(value: id))
            }
        }
    }

    func cancelRequest(id: Int, request: UUID) {
        lock.withLock {
            if requests[id] == request {
                requests.removeValue(forKey: id)
            }
        }
    }

    private func store(_ item: Item) {
        storage.setObject(
            Entry(item: item, expiresAt: now().addingTimeInterval(lifetime)),
            forKey: NSNumber(value: item.id)
        )
    }

    func removeAll() {
        lock.withLock {
            requests.removeAll()
            storage.removeAllObjects()
        }
    }
}
