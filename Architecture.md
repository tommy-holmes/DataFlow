# DataFlow Architecture

An exploration of DataFlow's design and the reasoning behind its core abstractions.

## Philosophy

DataFlow is built on a few core philosophical principles:

- **Separation of Concerns**: Data fetching, transformation, and orchestration are separate responsibilities
- **Type Safety**: The Swift type system should guide correct usage
- **Composability**: Simple pieces should combine to form more complex behaviors
- **Testability**: Every component should be independently testable without side effects
- **Thread Safety**: All types are `Sendable` and safe across task boundaries

These principles inform every design decision in the library.

## Core Abstractions

### DataSource<Type>

```swift
public struct DataSource<Type>: Sendable {
    public typealias FetchFunction = @Sendable (Type) async throws -> Data
    public var fetch: FetchFunction
    public init(fetch: @escaping FetchFunction)
}
```

`DataSource` is the simplest abstraction—it's just a closure that takes a request and returns data. This simplicity is intentional:

- **No Dependencies**: A data source can be created with just a closure, making it trivial to implement custom sources
- **No Hidden State**: The closure is pure (aside from async effects), so its behavior is predictable
- **Composable**: Data sources can be wrapped and modified without difficulty
- **Testable**: You can create mock sources with predetermined responses

The generic `Type` parameter allows `DataSource` to work with any request type, from `RESTRequest` to custom domain-specific requests.

### DataTransformer

```swift
public protocol DataTransformer: Sendable {
    associatedtype Input
    associatedtype Output
    func transform(_ data: Input) throws -> Output
}
```

A transformer handles one job: converting one type to another. Most commonly, this means converting raw `Data` to a `Decodable` model:

```swift
struct JSONTransformer<Model: Decodable>: DataTransformer {
    func transform(_ data: Data) throws -> Model {
        try JSONDecoder().decode(Model.self, from: data)
    }
}
```

But transformers can do anything:

- Parse CSV into models
- Decompress binary data
- Decrypt sensitive information
- Map one type to another with business logic

The `DataTransformer` protocol enforces that transformation is side-effect free (aside from errors), making transformers easy to reason about and test.

### ModelProvider

```swift
public protocol ModelProvider: Sendable {
    associatedtype Model
    associatedtype Transformer: DataTransformer
    associatedtype Request: Sendable

    var request: Request { get }
    var source: DataSource<Request> { get }
    var transformer: Transformer { get }

    func loadData() async throws -> Model
}
```

`ModelProvider` is where the pieces come together. It orchestrates a `DataSource` and `DataTransformer` into a complete pipeline:

```swift
func loadData() async throws -> Model {
    let data = try await source.fetch(request)
    return try transformer.transform(data)
}
```

This simple orchestration is the heart of DataFlow. Everything else builds on top of it.

The protocol exposes `request`, `source`, and `transformer` to enable middleware patterns like caching and retries.

## Design Patterns

### The Wrapper Pattern

DataFlow extensively uses the wrapper pattern for composability. A wrapper `ModelProvider` can enhance another `ModelProvider`:

```swift
struct CachedPipeline<Provider: ModelProvider>: ModelProvider {
    let wrapped: Provider

    var request: Provider.Request { wrapped.request }
    var source: DataSource<Provider.Request> { wrapped.source }
    var transformer: Provider.Transformer { wrapped.transformer }

    func loadData() async throws -> Provider.Model {
        if let cached = await cache.get(forKey: wrapped.request) {
            return cached
        }

        let result = try await wrapped.loadData()
        await cache.set(result, forKey: wrapped.request, ttl: ttl)
        return result
    }
}
```

This pattern allows you to:

- Add caching to any pipeline
- Add retry logic to any pipeline
- Add logging to any pipeline
- Add timeout handling to any pipeline

All without modifying the original pipeline.

### The Factory Pattern

DataFlow uses factory methods to create common data sources:

```swift
extension DataSource where Type == RESTRequest {
    static func liveAPI(baseUrl: URL, authProvider: AuthProvider) -> Self {
        DataSource { request in
            // Implementation
        }
    }
}
```

This makes creating common scenarios convenient while keeping `DataSource` simple and flexible.

### The Protocol Pattern

Rather than a base class or enum-based approach, DataFlow uses protocols (`DataTransformer` and `ModelProvider`) to define extensibility points. This allows:

- Multiple implementations of each abstraction
- Composition without inheritance
- Clear separation of concerns
- Easy testing with mock implementations

## Request Types

Request types are domain-specific and represent "what data you want":

```swift
struct RESTRequest: Sendable, Hashable {
    let path: String
    let queryItems: [URLQueryItem]
    let method: Method
    let body: Data?
}

struct CSVRequest: Sendable {
    let path: String
    let bundle: Bundle
    let hasHeader: Bool
}
```

Request types should:

- Be `Sendable` (safe across task boundaries)
- Be `Hashable` if they'll be used with `CachedPipeline`
- Be immutable (all properties should be `let`)
- Be minimal (only contain what's needed to fetch the data)

### Why Requests Are Generic

Different data sources need different information:

- REST APIs need paths, query parameters, and HTTP methods
- CSV files need paths and format information
- WebSockets need URLs and headers

By making `DataSource` generic over request type, each source can define exactly what it needs without unnecessary abstraction.

## Concurrency

DataFlow is built on Swift's structured concurrency:

- All types are `Sendable`, making them safe across task boundaries
- All async operations use `async/await`, not completion handlers
- Storage (like caches) uses `actor` for atomicity
- No global state or shared mutable state

This makes DataFlow safe to use in concurrent environments without locks or semaphores:

```swift
async let user1 = cachedPipeline.loadData()
async let user2 = cachedPipeline.loadData()

let (u1, u2) = try await (user1, user2)
```

Both calls are safe because:

- `cachedPipeline` is `Sendable`
- `cache` is an `actor`, so access is serialized
- No global state is modified

## Error Handling

Each implementation provides specific error types:

```swift
public enum HTTPError: Error {
    case badStatus(code: Int, data: Data?)
    case invalidResponse
}

public enum CSVError: Error, Sendable {
    case decodingFailed(String)
    case mismatchedColumns(row: Int, expected: Int, got: Int)
}
```

These specific error types allow callers to:

- Handle different errors differently
- Provide meaningful user feedback
- Log and report errors appropriately
- Implement recovery strategies

Error types are `Sendable` by storing descriptions rather than `Error` instances, making them safe across task boundaries.

## Extending DataFlow

Adding a new pipeline implementation requires:

1. **Define a Request Type**
   ```swift
   struct MyRequest: Sendable, Hashable {
       let parameter: String
   }
   ```

2. **Define a Transformer** (usually just JSON decoding)
   ```swift
   struct MyTransformer<D: Decodable>: DataTransformer {
       func transform(_ data: Data) throws -> D {
           try JSONDecoder().decode(D.self, from: data)
       }
   }
   ```

3. **Implement the Pipeline**
   ```swift
   struct MyPipeline<D: Decodable>: ModelProvider {
       let request: MyRequest
       var source: DataSource<MyRequest>
       var transformer: MyTransformer<D>

       func loadData() async throws -> D {
           let data = try await source.fetch(request)
           return try transformer.transform(data)
       }
   }
   ```

4. **Provide Factory Methods** (optional)
   ```swift
   extension DataSource where Type == MyRequest {
       static func mySource() -> Self {
           DataSource { request in
               // Implementation
           }
       }
   }
   ```

That's all there is to it. Your implementation immediately inherits:

- Composability (can be wrapped with caching, etc.)
- Type safety (generic over model type)
- Testability (mock sources work automatically)
- Thread safety (`Sendable` by default)

## Why Not...

### ...Use Generics Everywhere?

Using generics makes the library flexible but can create long type signatures. Instead, DataFlow provides concrete `RESTPipeline`, `CSVPipeline`, etc., while keeping the underlying abstractions generic.

### ...Use Inheritance?

Inheritance creates tight coupling and makes composition harder. Instead, DataFlow uses protocols and composition, allowing multiple independent implementations and clean wrapping patterns.

### ...Use Dependency Injection Containers?

Explicit dependency passing is simpler and more testable. Containers add complexity and hidden dependencies. DataFlow lets you choose how to manage dependencies.

### ...Cache Automatically?

Not all data should be cached, and cache policies are domain-specific. DataFlow provides `CachedPipeline` as an opt-in tool, not a default behavior.

### ...Use Reactive Primitives?

Reactive patterns can be powerful but add complexity. DataFlow uses simple async/await, which is easier to understand and debug, and composes well with Swift's structured concurrency.

## Performance Considerations

### Memory

- Each `DataSource` is essentially a closure, so memory overhead is minimal
- Transformers are typically stateless
- `CachedPipeline` uses an actor-based cache, which has reasonable memory overhead

### CPU

- No reflection or dynamic dispatch
- Direct protocol conformance check at compile time
- Minimal abstraction layers

### Network

- No implicit caching (you opt-in with `CachedPipeline`)
- No retry logic built-in (you implement it where appropriate)
- No request batching (you implement with `DataAggregationPipeline` when needed)

This gives you control over performance-critical decisions.

## Comparison to Other Approaches

### vs. Manual Fetching and Decoding

```swift
// Manual approach
let (data, _) = try await URLSession.shared.data(for: request)
let user = try JSONDecoder().decode(User.self, from: data)

// DataFlow approach
let user = try await pipeline.loadData()
```

DataFlow provides:
- Reusability (same pipeline in multiple places)
- Composability (add caching, etc.)
- Testability (mock easily)
- Type safety (request type is enforced)

### vs. Monolithic Networking Library

Rather than one large library that does everything, DataFlow is small and focused. You combine it with other libraries:

- Use `Foundation` or `HTTPClient` for networking
- Use `Decodable` for model decoding
- Use DataFlow to orchestrate them

This keeps each piece simple and replaceable.

### vs. Reactive Frameworks

Reactive frameworks like Combine or RxSwift are powerful but complex. DataFlow is simpler:

- Use async/await instead of reactive operators
- Simpler error handling (try/catch instead of error channels)
- Smaller learning curve
- Better IDE support and debugging

## Future Considerations

Possible future extensions to DataFlow:

- **Streaming**: A `StreamingProvider` protocol for real-time data streams
- **Retries**: Built-in retry middleware with exponential backoff
- **Logging**: Structured logging support for debugging
- **Pagination**: Built-in pagination support for list endpoints
- **GraphQL**: A GraphQL implementation alongside REST

These would all follow the same design principles: simple, composable, testable, and type-safe.

---

See also: [Guides](Guides.md) for practical examples, [API Reference](API_REFERENCE.md) for detailed API documentation.
