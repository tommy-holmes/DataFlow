import Testing
import Foundation
@testable import DataFlow

@Suite("Cached Pipeline")
struct CachedPipelineTests {

    @Test("CacheStorage stores and retrieves values")
    func cacheStorageStoresAndRetrievesValues() async throws {
        let cache = CacheStorage<String, Int>()

        await cache.set(42, forKey: "answer", ttl: nil)
        let value = await cache.get(forKey: "answer")

        #expect(value == 42)
    }

    @Test("CacheStorage returns nil for missing keys")
    func cacheStorageReturnsNilForMissingKeys() async throws {
        let cache = CacheStorage<String, Int>()

        let value = await cache.get(forKey: "missing")

        #expect(value == nil)
    }

    @Test("CacheStorage removes values on demand")
    func cacheStorageRemovesValuesOnDemand() async throws {
        let cache = CacheStorage<String, Int>()

        await cache.set(42, forKey: "answer", ttl: nil)
        await cache.remove(forKey: "answer")

        let value = await cache.get(forKey: "answer")
        #expect(value == nil)
    }

    @Test("CacheStorage clears all entries")
    func cacheStorageClearsAllEntries() async throws {
        let cache = CacheStorage<String, Int>()

        await cache.set(1, forKey: "one", ttl: nil)
        await cache.set(2, forKey: "two", ttl: nil)
        await cache.set(3, forKey: "three", ttl: nil)

        await cache.clear()

        let one = await cache.get(forKey: "one")
        let two = await cache.get(forKey: "two")
        let three = await cache.get(forKey: "three")

        #expect(one == nil)
        #expect(two == nil)
        #expect(three == nil)
    }

    @Test("CacheEntry tracks timestamp")
    func cacheEntryTracksTimestamp() throws {
        let now = Date()
        let entry = CacheEntry(value: 42, timestamp: now, ttl: nil)

        #expect(entry.timestamp == now)
        #expect(entry.value == 42)
    }

    @Test("CacheEntry with TTL detects expiration")
    func cacheEntryDetectsExpiration() throws {
        let pastDate = Date().addingTimeInterval(-10)  // 10 seconds ago
        let entry = CacheEntry(value: 42, timestamp: pastDate, ttl: 5)  // 5 second TTL

        #expect(entry.isExpired == true)
    }

    @Test("CacheEntry without TTL never expires")
    func cacheEntryNeverExpiresWithoutTTL() throws {
        let pastDate = Date().addingTimeInterval(-1000)  // Long ago
        let entry = CacheEntry(value: 42, timestamp: pastDate, ttl: nil)

        #expect(entry.isExpired == false)
    }

    @Test("TypedCachedPipeline works with REST pipeline")
    func typedCachedPipelineWithRESTPipeline() async throws {
        let mockSource = DataSource<RESTRequest> { _ in
            let jsonData = """
            {
                "id": 1,
                "name": "John Doe",
                "email": "john@example.com"
            }
            """.data(using: .utf8)!
            return jsonData
        }

        let restPipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: mockSource
        )

        let cachedPipeline = TypedCachedPipeline(
            wrapping: restPipeline,
            cacheKey: { "user-1" },
            ttl: 60
        )

        let user = try await cachedPipeline.loadData()
        #expect(user.id == 1)
    }

    @Test("CachedPipeline propagates source errors")
    func cachedPipelinePropagatesSourceErrors() async throws {
        enum CustomError: Error {
            case networkFailure
        }

        let failingSource = DataSource<RESTRequest> { _ in
            throw CustomError.networkFailure
        }

        let restPipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: failingSource
        )

        let cachedPipeline = TypedCachedPipeline(
            wrapping: restPipeline,
            cacheKey: { "user-1" },
            ttl: 60
        )

        await #expect(throws: CustomError.self) {
            try await cachedPipeline.loadData()
        }
    }
}
