# Flux

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
     [![iOS 16+](https://img.shields.io/badge/iOS-16+-blue.svg)](https://developer.apple.c
     om/ios/)
     [![macOS 14+](https://img.shields.io/badge/macOS-14+-lightgrey.svg)](https://www.appl
     e.com/macos/)
     [![visionOS 1+](https://img.shields.io/badge/visionOS-1+-purple.svg)](https://www.app
     le.com/visionos/)
     [![watchOS 10+](https://img.shields.io/badge/watchOS-10+-blueviolet.svg)](https://www
     .apple.com/watchos/)
     [![tvOS
     16+](https://img.shields.io/badge/tvOS-16+-ff69b4.svg)](https://www.apple.com/tv/)
     [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://openso
     urce.org/licenses/MIT)
     [![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](http
     s://swift.org/package-manager/)

A composable, type-safe library for building reusable data pipelines in Swift.

DataFlow provides a clean abstraction for fetching and transforming data from any source—REST APIs, local files, databases, WebSockets, or your own custom sources. Built from the ground up with modern Swift concurrency, type safety, and composability in mind.

## Motivation

Data fetching is a fundamental operation in most applications, yet the implementations often vary widely:

- Some parts fetch from a REST API and decode JSON
- Others load configuration files from the bundle
- A few might parse CSV data or stream from WebSockets
- And most would benefit from caching to reduce redundant work

Rather than implementing these patterns repeatedly across your codebase, DataFlow provides a unified, extensible architecture that works the same way whether you're fetching from a network request or a local file. This makes your code more testable, reusable, and maintainable.

## Quick Start

```swift
// Fetch and decode a user from a REST API
let pipeline = RESTPipeline<User>(
    request: RESTRequest(path: "/users/1"),
    source: .liveAPI(
        baseUrl: URL(string: "https://api.example.com")!,
        authProvider: .bearerToken("token")
    )
)

let user = try await pipeline.loadData()
```

That's it. No boilerplate, no intermediate types, just a simple pipeline that fetches and decodes data.

## Key Ideas

### Separation of Concerns

DataFlow separates data fetching into three distinct concerns:

1. **DataSource**: Responsible for fetching raw data
2. **DataTransformer**: Responsible for transforming raw data into models
3. **ModelProvider**: Orchestrates a source and transformer

This separation makes each part independently testable and reusable.

### Type Safety

Every pipeline is generic over its model type and request type. The Swift type system ensures that your data flows correctly from source through transformer to output—mistakes are caught at compile time, not runtime.

### Composability

Pipelines compose naturally with Swift's async/await. Wrap one pipeline in another to add caching, implement error recovery with fallbacks, or combine multiple pipelines into a single result.

```swift
// Add caching to any pipeline
let cached = CachedPipeline(wrapping: pipeline, ttl: 300)

// Combine multiple pipelines
async let user = userPipeline.loadData()
async let posts = postsPipeline.loadData()
let (u, p) = try await (user, posts)
```

### Extensibility

Built-in implementations cover the common cases (REST, CSV, files, WebSockets), but you can easily implement custom pipelines for your domain-specific needs. A complete implementation is just a few lines of code.

```swift
struct MyPipeline<D: Decodable>: ModelProvider {
    let request: MyRequest
    var source: DataSource<MyRequest>
    var transformer: JSONTransformer<D>

    init(request: MyRequest, source: DataSource<MyRequest>) {
        self.request = request
        self.source = source
        self.transformer = JSONTransformer<D>()
    }

    func loadData() async throws -> D {
        let data = try await source.fetch(request)
        return try transformer.transform(data)
    }
}
```

## Documentation

- **[Guides & Examples](Guides.md)** — Learn how to use DataFlow through practical examples
- **[API Reference](API_REFERENCE.md)** — Complete API documentation
- **[Architecture](Architecture.md)** — Deep dive into the design and core concepts

## Built-in Implementations

### REST Pipeline

Load data from HTTP/HTTPS APIs with built-in support for authentication, query parameters, and various HTTP methods.

### CSV Pipeline

Parse CSV files into arrays of strongly-typed models, with support for quoted fields and custom headers.

### FileSystem Pipeline

Load JSON or PropertyList files from your app bundle or file system.

### WebSocket Pipeline

Connect to WebSocket endpoints and decode incoming messages.

### Cached Pipeline

Add transparent caching with TTL-based expiration to any pipeline.

### Data Aggregation Pipeline

Combine results from multiple pipelines into a single aggregated result.

## Requirements

- Swift 5.10+
- iOS 16+, macOS 14+, visionOS 1+, watchOS 10+, tvOS 16+

## Installation

### Swift Package Manager

Add DataFlow to your `Package.swift`:

```swift
.package(url: "https://github.com/tommy-holmes/Flux.git", from: "0.2.0")
```

Or in Xcode: File → Add Packages → enter the repository URL.

## Testing

DataFlow is designed to be highly testable. Use mock data sources in your tests:

```swift
let mockData = """
{
    "id": 1,
    "name": "Test User"
}
""".data(using: .utf8)!

let mockSource = DataSource<RESTRequest> { _ in mockData }
let pipeline = RESTPipeline<User>(
    request: RESTRequest(path: "/test"),
    source: mockSource
)

let user = try await pipeline.loadData()
XCTAssertEqual(user.name, "Test User")
```

## Design Philosophy

DataFlow follows several core principles:

- **Simplicity**: The API should be easy to understand and use
- **Composability**: Components should work well together
- **Type Safety**: Errors should be caught at compile time
- **Testability**: No hidden dependencies or global state
- **Thread Safety**: All types are `Sendable` and safe across task boundaries
- **Modern Swift**: Built on async/await and structured concurrency

## License

MIT

## Contributing

Contributions are welcome! Please feel free to open issues or submit pull requests.
