import Foundation

actor CacheStorage<Key: Hashable & Sendable, Value: Sendable> {
    private var cache: [Key: CacheEntry<Value>] = [:]

    func set(_ value: Value, forKey key: Key, ttl: TimeInterval?) {
        cache[key] = CacheEntry(value: value, timestamp: Date(), ttl: ttl)
    }

    func get(forKey key: Key) -> Value? {
        guard let entry = cache[key], !entry.isExpired else {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.value
    }

    func remove(forKey key: Key) {
        cache.removeValue(forKey: key)
    }

    func clear() {
        cache.removeAll()
    }
}
