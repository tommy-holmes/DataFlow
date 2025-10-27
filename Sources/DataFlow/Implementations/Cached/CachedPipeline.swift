import Foundation

/// A caching wrapper for any `ModelProvider` pipeline.
///
/// `CachedPipeline` transparently caches results from any pipeline, reducing redundant
/// data fetches. It uses Time-To-Live (TTL) based expiration for cache entries.
///
/// ## Usage
///
/// ```swift
/// let restPipeline = RESTPipeline(
///     request: RESTRequest(path: "/users/1"),
///     source: DataSource.liveAPI(baseUrl: url, authProvider: .none)
/// )
///
/// let cachedPipeline = CachedPipeline(wrapping: restPipeline, ttl: 300) // 5 minute TTL
///
/// // First call fetches from network
/// let user = try await cachedPipeline.loadData()
///
/// // Subsequent calls within 5 minutes return cached value
/// let cachedUser = try await cachedPipeline.loadData()
/// ```
///
/// ## Cache Key
/// Cache keys are derived from the request. For caching to work effectively, your
/// request type must conform to `Hashable`.
public struct CachedPipeline<Provider: ModelProvider>: ModelProvider
where Provider.Request: Hashable & Sendable, Provider.Model: Sendable {
    /// The wrapped pipeline being cached.
    public let wrapped: Provider

    /// The underlying cache storage.
    private let cache: CacheStorage<Provider.Request, Provider.Model>

    /// Time-to-live for cache entries. `nil` means no expiration.
    private let ttl: TimeInterval?

    /// The request being cached.
    public var request: Provider.Request {
        wrapped.request
    }

    public var source: DataSource<Provider.Request> {
        wrapped.source
    }

    public var transformer: Provider.Transformer {
        wrapped.transformer
    }

    /// Creates a new cached pipeline wrapper.
    ///
    /// - Parameters:
    ///   - wrapped: The pipeline to wrap with caching
    ///   - ttl: Time-to-live in seconds. `nil` = cache forever, `0` = no caching
    public init(
        wrapping wrapped: Provider,
        ttl: TimeInterval? = nil
    ) {
        self.wrapped = wrapped
        self.cache = CacheStorage<Provider.Request, Provider.Model>()
        self.ttl = ttl
    }

    /// Loads data, returning cached value if available and not expired.
    ///
    /// - Returns: The cached or newly-fetched model
    /// - Throws: Errors from the wrapped pipeline
    public func loadData() async throws -> Provider.Model {
        // Check cache first
        if let cached = await cache.get(forKey: wrapped.request) {
            return cached
        }

        // Cache miss - fetch from wrapped pipeline
        let result = try await wrapped.loadData()

        // Store in cache
        await cache.set(result, forKey: wrapped.request, ttl: ttl)

        return result
    }
}

/// Alternative cached pipeline for use cases where the request type isn't Hashable.
///
/// This version uses string keys instead of the request itself, providing flexibility
/// for requests that don't conform to `Hashable`.
public struct TypedCachedPipeline<Provider: ModelProvider>: ModelProvider
where Provider.Model: Sendable {
    public let wrapped: Provider
    public var source: DataSource<Provider.Request> {
        wrapped.source
    }

    public var transformer: Provider.Transformer {
        wrapped.transformer
    }

    public var request: Provider.Request {
        wrapped.request
    }

    private let cache: CacheStorage<String, Provider.Model>
    private let ttl: TimeInterval?
    private let cacheKeyProvider: @Sendable () -> String

    public init(
        wrapping provider: Provider,
        cacheKey: @escaping @Sendable () -> String,
        ttl: TimeInterval? = nil
    ) {
        self.wrapped = provider
        self.cache = CacheStorage<String, Provider.Model>()
        self.ttl = ttl
        self.cacheKeyProvider = cacheKey
    }

    public func loadData() async throws -> Provider.Model {
        let cacheKey = cacheKeyProvider()

        if let cachedModel = await cache.get(forKey: cacheKey) {
            return cachedModel
        }

        let result = try await wrapped.loadData()
        await cache.set(result, forKey: cacheKey, ttl: ttl)

        return result
    }
}
