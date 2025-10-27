# DataFlow Implementation Guide

Complete guide to using the DataFlow library for building composable, extensible data pipelines in Swift.

## Table of Contents

1. [Overview](#overview)
2. [Core Concepts](#core-concepts)
3. [Built-in Implementations](#built-in-implementations)
4. [Advanced Patterns](#advanced-patterns)
5. [Best Practices](#best-practices)

---

## Overview

DataFlow is a Swift library for building reusable data pipelines that follow the Open/Closed Principle. It provides a clean abstraction for fetching and transforming data from any source—REST APIs, files, databases, WebSockets, or custom sources.

### Key Features

- **Composable**: Chain multiple pipelines together
- **Extensible**: Easy to implement custom pipelines
- **Type-Safe**: Full Swift type system integration
- **Concurrent**: Built on modern async/await
- **Testable**: Easy to mock data sources
- **Cacheable**: Built-in caching with TTL support

---

## Core Concepts

### 1. DataSource

A `DataSource` is responsible for fetching raw data:

```swift
public struct DataSource<Type>: Sendable {
    public typealias FetchFunction = @Sendable (Type) async throws -> Data

    public var fetch: FetchFunction

    public init(fetch: @escaping FetchFunction) {
        self.fetch = fetch
    }
}
```

**Example**: Creating a simple in-memory data source:

```swift
let mockSource = DataSource<RESTRequest> { request in
    """
    {
        "id": 1,
        "name": "John Doe",
        "email": "john@example.com"
    }
    """.data(using: .utf8)!
}
```

### 2. DataTransformer

A `DataTransformer` converts raw data into strongly-typed models:

```swift
public protocol DataTransformer: Sendable {
    associatedtype Input
    associatedtype Output

    func transform(_ data: Input) throws -> Output
}
```

**Example**: JSON transformer (built-in):

```swift
struct JSONTransformer<Model: Decodable>: DataTransformer {
    func transform(_ data: Data) throws -> Model {
        try JSONDecoder().decode(Model.self, from: data)
    }
}
```

### 3. ModelProvider

A `ModelProvider` orchestrates a data source and transformer into a complete pipeline:

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

**Example**: A complete pipeline:

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

---

## Built-in Implementations

### REST Pipeline

Load data from HTTP/HTTPS REST APIs:

```swift
import DataFlow

// Create a pipeline
let pipeline = RESTPipeline<User>(
    request: RESTRequest(path: "/users/1"),
    source: DataSource<RESTRequest>.liveAPI(
        baseUrl: URL(string: "https://api.example.com")!,
        authProvider: .bearerToken("your-token")
    )
)

// Load data
let user = try await pipeline.loadData()
```

**Features**:
- Automatic URL construction with query parameters
- Multiple authentication providers (bearer token, JWT with refresh)
- ISO8601 date decoding
- Proper error handling with HTTP status codes

**Request Construction**:

```swift
// Simple GET
RESTRequest(path: "/users")

// With query parameters
RESTRequest(
    path: "/users",
    queryItems: [
        URLQueryItem(name: "page", value: "1"),
        URLQueryItem(name: "limit", value: "10")
    ]
)

// POST with body
let body = try JSONEncoder().encode(newUser)
RESTRequest(path: "/users", method: .post, body: body)

// Different HTTP methods
RESTRequest(path: "/users/1", method: .put)
RESTRequest(path: "/users/1", method: .delete)
```

---

### CSV Pipeline

Load and parse CSV files:

```swift
// Define your model
struct Person: Decodable {
    let name: String
    let email: String
}

// Create pipeline
let pipeline = CSVPipeline<Person>(
    request: CSVRequest(path: "people"),
    source: DataSource<CSVRequest>.fromBundle()
)

// Load data
let people = try await pipeline.loadData()
```

**Features**:
- Bundle resource loading
- Header row parsing
- Quoted field handling
- Column count validation

**Request Construction**:

```swift
// Load from bundle (looks for people.csv)
CSVRequest(path: "people")

// Custom bundle
CSVRequest(path: "people", bundle: myBundle)

// Specify if first row is header (default: true)
CSVRequest(path: "data", hasHeader: false)
```

**CSV Format Example**:

```
name,email
John Doe,john@example.com
Jane Smith,jane@example.com
```

**Important**: CSV values are parsed as strings, so your Decodable model must accept string types for numeric fields, or the decoding will fail. For numeric types, either:
1. Define fields as `String` in your model
2. Implement custom `Decodable` with string-to-number conversion
3. Pre-process the CSV data

---

### FileSystem Pipeline

Load JSON or PropertyList files:

```swift
// Load JSON from bundle
let pipeline = FileSystemPipeline<User>(
    request: FileSystemRequest(path: "user", format: .json),
    source: DataSource<FileSystemRequest>.fromBundle()
)

let user = try await pipeline.loadData()

// Load from custom directory
let customPipeline = FileSystemPipeline<Config>(
    request: FileSystemRequest(
        path: "config.plist",
        format: .propertyList
    ),
    source: DataSource<FileSystemRequest>.fromFileManager(at: "/path/to/files")
)

let config = try await customPipeline.loadData()
```

**Features**:
- JSON support
- PropertyList (plist) support
- Bundle and FileManager sources
- Automatic extension handling
- Proper error reporting with file paths

**Request Construction**:

```swift
// JSON (looks for user.json)
FileSystemRequest(path: "user", format: .json)

// PropertyList (looks for settings.plist)
FileSystemRequest(path: "settings", format: .propertyList)

// Custom bundle
FileSystemRequest(path: "user", bundle: myBundle, format: .json)

// From file system
let fsSource = DataSource<FileSystemRequest>.fromFileManager(
    at: "/Users/me/Documents"
)
```

---

### WebSocket Pipeline

Real-time data streaming via WebSocket:

```swift
struct Message: Decodable {
    let id: String
    let text: String
}

// Create pipeline
let pipeline = WebSocketPipeline<Message>(
    request: WebSocketRequest(
        url: URL(string: "wss://example.com/stream")!,
        headers: ["Authorization": "Bearer token"],
        messageCount: 1
    ),
    source: DataSource<WebSocketRequest>.liveWebSocket()
)

// Load first message
let message = try await pipeline.loadData()
```

**Features**:
- Automatic URL connection management
- Custom header support
- Message count limiting
- Proper error handling

**Request Construction**:

```swift
// Basic connection
WebSocketRequest(url: wsURL)

// With custom headers
WebSocketRequest(
    url: wsURL,
    headers: ["Authorization": "Bearer token"]
)

// Limit message count
WebSocketRequest(url: wsURL, messageCount: 5)

// Unlimited messages (note: will block until error)
WebSocketRequest(url: wsURL, messageCount: nil)
```

**Note**: The current implementation loads a single message. For streaming applications, consider building a custom `StreamingProvider`.

---

### Data Aggregation Pipeline

Combine results from multiple pipelines:

```swift
// Fetch from multiple REST endpoints
let requests = [
    RESTRequest(path: "/users/1"),
    RESTRequest(path: "/users/2"),
    RESTRequest(path: "/users/3")
]

let aggregation = AggregationRequest(
    identifier: "users-batch",
    subRequests: requests
)

let source = DataSource<AggregationRequest<RESTRequest>>.aggregating(
    pipelines: [restSource],
    parallelFetch: true
)

let pipeline = DataAggregationPipeline(
    request: aggregation,
    source: source
)

let results = try await pipeline.loadData()
```

**Features**:
- Parallel and sequential execution
- Multiple pipeline support
- Proper error propagation

**Request Construction**:

```swift
// Define sub-requests
let subRequests = [
    RESTRequest(path: "/api/1"),
    RESTRequest(path: "/api/2")
]

// Create aggregation
let aggregation = AggregationRequest(
    identifier: "batch-operation",
    subRequests: subRequests
)
```

---

### Cached Pipeline

Add caching to any pipeline:

```swift
let restPipeline = RESTPipeline<User>(
    request: RESTRequest(path: "/users/1"),
    source: DataSource.liveAPI(baseUrl: url, authProvider: .none)
)

// Wrap with caching (5 minute TTL)
let cachedPipeline = CachedPipeline(
    wrapping: restPipeline,
    ttl: 300
)

// First call fetches from network
let user = try await cachedPipeline.loadData()

// Subsequent calls within 5 minutes return cached value
let cachedUser = try await cachedPipeline.loadData()
```

**Features**:
- Automatic caching by request
- TTL-based expiration
- Thread-safe with actors
- Works with any pipeline

**Cache Configuration**:

```swift
// No expiration (cache forever)
CachedPipeline(wrapping: pipeline, ttl: nil)

// 5 minute TTL
CachedPipeline(wrapping: pipeline, ttl: 300)

// 1 hour TTL
CachedPipeline(wrapping: pipeline, ttl: 3600)

// Disable caching (0 TTL)
CachedPipeline(wrapping: pipeline, ttl: 0)
```

**Important**: The `Request` type must conform to `Hashable` for caching to work. If your request type doesn't conform, use `TypedCachedPipeline` with custom string keys instead.

---

## Advanced Patterns

### Custom Pipeline Implementation

Create your own pipeline for specialized data sources:

```swift
// 1. Define your request type
public struct DatabaseRequest: Sendable, Hashable {
    public let query: String
    public let parameters: [String: Any]
}

// 2. Define your transformer
public struct DatabaseTransformer<Model: Decodable>: DataTransformer {
    public func transform(_ data: Data) throws -> Model {
        try JSONDecoder().decode(Model.self, from: data)
    }
}

// 3. Implement your pipeline
public struct DatabasePipeline<D: Decodable>: ModelProvider {
    public let request: DatabaseRequest
    public var source: DataSource<DatabaseRequest>
    public var transformer: DatabaseTransformer<D>

    public init(
        request: DatabaseRequest,
        source: DataSource<DatabaseRequest>
    ) {
        self.request = request
        self.source = source
        self.transformer = DatabaseTransformer<D>()
    }

    public func loadData() async throws -> D {
        let data = try await source.fetch(request)
        return try transformer.transform(data)
    }
}

// 4. Create data source
public extension DataSource where Type == DatabaseRequest {
    static func liveDatabase(connection: Database) -> Self {
        DataSource { request in
            let results = try await connection.query(
                request.query,
                parameters: request.parameters
            )
            return try JSONEncoder().encode(results)
        }
    }
}

// 5. Use your pipeline
let pipeline = DatabasePipeline<User>(
    request: DatabaseRequest(
        query: "SELECT * FROM users WHERE id = ?",
        parameters: ["id": 1]
    ),
    source: DataSource.liveDatabase(connection: db)
)

let user = try await pipeline.loadData()
```

### Composing Pipelines with Error Recovery

Chain pipelines with fallback logic:

```swift
// Try REST first, fall back to cached version
async func loadUserWithFallback(id: Int) async throws -> User {
    let restPipeline = RESTPipeline<User>(
        request: RESTRequest(path: "/users/\(id)"),
        source: DataSource.liveAPI(baseUrl: url, authProvider: .none)
    )

    do {
        return try await restPipeline.loadData()
    } catch {
        // Network error - try loading from local cache/file
        let filePipeline = FileSystemPipeline<User>(
            request: FileSystemRequest(path: "user_\(id)"),
            source: DataSource.fromBundle()
        )

        return try await filePipeline.loadData()
    }
}

let user = try await loadUserWithFallback(id: 1)
```

### Multi-Model Pipelines

Load and combine multiple models:

```swift
struct UserProfile {
    let user: User
    let posts: [Post]
    let comments: [Comment]
}

func loadUserProfile(id: Int) async throws -> UserProfile {
    // Load user
    let userPipeline = RESTPipeline<User>(
        request: RESTRequest(path: "/users/\(id)"),
        source: DataSource.liveAPI(baseUrl: url, authProvider: .none)
    )
    let user = try await userPipeline.loadData()

    // Load posts
    let postsPipeline = RESTPipeline<[Post]>(
        request: RESTRequest(path: "/users/\(id)/posts"),
        source: DataSource.liveAPI(baseUrl: url, authProvider: .none)
    )
    let posts = try await postsPipeline.loadData()

    // Load comments
    let commentsPipeline = RESTPipeline<[Comment]>(
        request: RESTRequest(path: "/users/\(id)/comments"),
        source: DataSource.liveAPI(baseUrl: url, authProvider: .none)
    )
    let comments = try await commentsPipeline.loadData()

    // Combine all data
    return UserProfile(user: user, posts: posts, comments: comments)
}

let profile = try await loadUserProfile(id: 1)
```

---

## Best Practices

### 1. Always Use Concrete Request Types

```swift
// ✅ Good: Type-safe and self-documenting
let pipeline = RESTPipeline<User>(
    request: RESTRequest(path: "/users/1"),
    source: dataSource
)

// ❌ Avoid: Generic/ambiguous
let data = try await source.fetch(someRequest)
```

### 2. Expose Request for Caching

```swift
// ✅ Good: Request exposed, cacheable
struct MyPipeline: ModelProvider {
    let request: MyRequest  // Public for caching
    // ...
}

// ❌ Avoid: Request hidden
struct MyPipeline: ModelProvider {
    private let request: MyRequest  // Not accessible for caching
    // ...
}
```

### 3. Use Hashable Requests for Caching

```swift
// ✅ Good: Request is Hashable, works with CachedPipeline
public struct MyRequest: Sendable, Hashable {
    public let id: Int
    // ...
}

let cached = CachedPipeline(wrapping: pipeline, ttl: 300)

// ⚠️ If not Hashable: Use TypedCachedPipeline instead
let cached = TypedCachedPipeline(
    wrapping: pipeline,
    cacheKey: { "user-\(pipeline.request.id)" },
    ttl: 300
)
```

### 4. Handle Errors Explicitly

```swift
// ✅ Good: Specific error handling
do {
    let user = try await pipeline.loadData()
} catch let error as FileSystemError {
    logger.error("File error: \(error)")
} catch let error as CSVError {
    logger.error("CSV error: \(error)")
} catch {
    logger.error("Unknown error: \(error)")
}

// ❌ Avoid: Generic error handling
try await pipeline.loadData()  // Ignores errors
```

### 5. Reuse Pipelines and Sources

```swift
// ✅ Good: Create once, reuse many times
let apiSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: apiURL,
    authProvider: .bearerToken(token)
)

let userPipeline = RESTPipeline<User>(
    request: RESTRequest(path: "/users/1"),
    source: apiSource
)

let postsPipeline = RESTPipeline<[Post]>(
    request: RESTRequest(path: "/posts"),
    source: apiSource
)

// ❌ Avoid: Creating new sources for each request
let user1 = try await RESTPipeline<User>(
    request: RESTRequest(path: "/users/1"),
    source: DataSource.liveAPI(baseUrl: url, authProvider: .none)
).loadData()

let user2 = try await RESTPipeline<User>(
    request: RESTRequest(path: "/users/2"),
    source: DataSource.liveAPI(baseUrl: url, authProvider: .none)
).loadData()
```

### 6. Test with Mock Sources

```swift
// ✅ Good: Easy to test with mocks
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

// ❌ Avoid: Testing with real network
let pipeline = RESTPipeline<User>(
    request: RESTRequest(path: "/users/1"),
    source: DataSource.liveAPI(baseUrl: url, authProvider: .none)
)
```

### 7. Use Proper Error Types

```swift
// ✅ Good: Sendable errors with context
public enum MyError: Error, Sendable {
    case notFound(id: Int)
    case invalidData(description: String)
    case networkError(statusCode: Int)
}

// ❌ Avoid: Non-Sendable errors
public enum MyError: Error {
    case failure(Error)  // Not Sendable!
}
```

### 8. Leverage Actor-Based Caching

```swift
// ✅ Good: Thread-safe caching
let cached = CachedPipeline(wrapping: pipeline, ttl: 300)

async let user1 = cached.loadData()
async let user2 = cached.loadData()

let (u1, u2) = try await (user1, user2)
// u2 uses cached value from u1
```

---

## Error Handling Reference

### REST Pipeline Errors

```swift
public enum HTTPError: Error {
    case badStatus(code: Int, data: Data?)
    case invalidResponse
}
```

### CSV Pipeline Errors

```swift
public enum CSVError: Error, Sendable {
    case decodingFailed(String)
    case mismatchedColumns(row: Int, expected: Int, got: Int)
    case modelDecodingFailed(String)
}

public enum CSVSourceError: Error, Sendable {
    case fileNotFound(String)
    case readFailed(path: String, description: String)
}
```

### FileSystem Pipeline Errors

```swift
public enum FileSystemError: Error, Sendable {
    case fileNotFound(String)
    case readFailed(path: String, description: String)
    case decodingFailed(description: String)
    case rawFormatRequiresManualDecoding
}
```

### WebSocket Pipeline Errors

```swift
public enum WebSocketError: Error, Sendable {
    case connectionFailed(Error)
    case noDataReceived
    case invalidURL
}
```

---

## Common Patterns

### Conditional Caching

```swift
func loadUser(id: Int, useCache: Bool = true) async throws -> User {
    let pipeline = RESTPipeline<User>(
        request: RESTRequest(path: "/users/\(id)"),
        source: DataSource.liveAPI(baseUrl: url, authProvider: .none)
    )

    if useCache {
        let cached = CachedPipeline(wrapping: pipeline, ttl: 300)
        return try await cached.loadData()
    } else {
        return try await pipeline.loadData()
    }
}
```

### Chained Transformations

```swift
struct ProcessingPipeline: ModelProvider {
    let request: MyRequest
    var source: DataSource<MyRequest>

    // Chain multiple transformations
    var transformer: ProcessingTransformer {
        ProcessingTransformer()
    }

    func loadData() async throws -> ProcessedModel {
        let rawData = try await source.fetch(request)
        let validated = try JSONDecoder().decode(RawModel.self, from: rawData)
        let processed = try validated.process()
        return processed
    }
}
```

---

## Summary

DataFlow provides a clean, extensible foundation for data pipelines in Swift. By understanding these core concepts and patterns, you can build robust, testable applications that handle complex data flows with elegance and type safety.

Key takeaways:
- Use the protocol-based design for flexibility
- Leverage built-in implementations for common cases
- Create custom pipelines for specialized sources
- Use caching strategically for performance
- Handle errors explicitly
- Test with mock sources
