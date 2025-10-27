import Foundation

struct CacheEntry<T: Sendable>: Sendable {
    let value: T
    let timestamp: Date
    let ttl: TimeInterval?

    var isExpired: Bool {
        guard let ttl else { return false }
        return Date().timeIntervalSince(timestamp) > ttl
    }
}
