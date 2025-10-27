# DataFlow Guides

Practical guides and examples for using DataFlow in your Swift applications.

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [REST APIs](#rest-apis)
3. [Local Files](#local-files)
4. [CSV Data](#csv-data)
5. [Real-time Data](#real-time-data)
6. [Caching](#caching)
7. [Custom Pipelines](#custom-pipelines)
8. [Combining Pipelines](#combining-pipelines)
9. [Error Handling](#error-handling)

---

## Core Concepts

At the heart of DataFlow are three simple concepts: `DataSource`, `DataTransformer`, and `ModelProvider`.

### DataSource

A `DataSource` is responsible for fetching raw bytes of data. It's defined as a simple closure that takes a request and returns data.

```swift
let source = DataSource<RESTRequest> { request in
    let (data, _) = try await URLSession.shared.data(for: makeURLRequest(from: request))
    return data
}
```

You don't typically create data sources directly—DataFlow provides factory methods for common cases. But you can always create your own for testing or custom scenarios.

### DataTransformer

A `DataTransformer` takes raw data and converts it into a strongly-typed model. Most commonly, you'll use `JSONTransformer` to decode JSON into a Decodable model:

```swift
let transformer = JSONTransformer<User>()
let user = try transformer.transform(jsonData)
```

You can also implement custom transformers for specialized formats.

### ModelProvider

A `ModelProvider` combines a data source and transformer into a complete pipeline. It knows how to fetch raw data and decode it into your model:

```swift
struct MyPipeline<D: Decodable>: ModelProvider {
    let request: MyRequest
    var source: DataSource<MyRequest>
    var transformer: JSONTransformer<D>

    func loadData() async throws -> D {
        let data = try await source.fetch(request)
        return try transformer.transform(data)
    }
}
```

The `ModelProvider` protocol is what makes DataFlow composable—you can wrap one pipeline in another to add behavior like caching.

---

## REST APIs

Loading data from REST APIs is the most common use case for DataFlow.

### Basic Usage

```swift
let pipeline = RESTPipeline<User>(
    request: RESTRequest(path: "/users/1"),
    source: DataSource<RESTRequest>.liveAPI(
        baseUrl: URL(string: "https://api.example.com")!,
        authProvider: .none
    )
)

let user = try await pipeline.loadData()
```

### Query Parameters

Add query parameters to your requests:

```swift
let request = RESTRequest(
    path: "/users",
    queryItems: [
        URLQueryItem(name: "page", value: "1"),
        URLQueryItem(name: "limit", value: "10")
    ]
)

let pipeline = RESTPipeline<[User]>(
    request: request,
    source: dataSource
)

let users = try await pipeline.loadData()
```

### Different HTTP Methods

RESTRequest supports GET, POST, PUT, PATCH, and DELETE:

```swift
// POST with a body
let body = try JSONEncoder().encode(newUser)
let request = RESTRequest(
    path: "/users",
    method: .post,
    body: body
)

// DELETE
let deleteRequest = RESTRequest(
    path: "/users/1",
    method: .delete
)
```

### Authentication

DataFlow supports multiple authentication strategies:

```swift
// No authentication
.liveAPI(baseUrl: url, authProvider: .none)

// Bearer token
.liveAPI(baseUrl: url, authProvider: .bearerToken("your-token"))

// JWT with automatic refresh
.liveAPI(baseUrl: url, authProvider: .jwtProvider(jwtProvider))
```

The JWT provider automatically handles token refresh when needed, keeping your code simple and your tokens fresh.

### Error Handling

REST operations can fail for various reasons. The `HTTPError` enum captures the most common scenarios:

```swift
do {
    let user = try await pipeline.loadData()
} catch let error as HTTPError {
    switch error {
    case .badStatus(let code, let data):
        print("HTTP \(code) error, response: \(data ?? Data())")
    case .invalidResponse:
        print("Invalid or missing response from server")
    }
} catch {
    print("Other error: \(error)")
}
```

---

## Local Files

Loading data from local files is simpler than network requests and doesn't require external dependencies.

### Loading from Bundle

Load files that are bundled with your app:

```swift
let pipeline = FileSystemPipeline<Config>(
    request: FileSystemRequest(path: "config", format: .json),
    source: DataSource<FileSystemRequest>.fromBundle()
)

let config = try await pipeline.loadData()
```

DataFlow automatically handles the file extension based on the format (`.json` for JSON, `.plist` for PropertyList).

### Loading from Documents Directory

Load files from your app's Documents directory or other file system locations:

```swift
let documentsPath = NSSearchPathForDirectoriesInDomains(
    .documentDirectory, .userDomainMask, true
)[0]

let pipeline = FileSystemPipeline<SavedData>(
    request: FileSystemRequest(path: "data.json", format: .json),
    source: DataSource<FileSystemRequest>.fromFileManager(at: documentsPath)
)

let data = try await pipeline.loadData()
```

### PropertyList Format

DataFlow supports PropertyList files in addition to JSON:

```swift
let pipeline = FileSystemPipeline<AppSettings>(
    request: FileSystemRequest(path: "settings", format: .propertyList),
    source: DataSource<FileSystemRequest>.fromBundle()
)

let settings = try await pipeline.loadData()
```

Your model must conform to `Decodable` for any format you use.

---

## CSV Data

CSV files are common in business applications and data science workflows. DataFlow provides first-class support for CSV parsing.

### Loading CSV Files

```swift
struct Person: Decodable {
    let name: String
    let email: String
}

let pipeline = CSVPipeline<Person>(
    request: CSVRequest(path: "people"),
    source: DataSource<CSVRequest>.fromBundle()
)

let people = try await pipeline.loadData()
```

### CSV Format

Your CSV file should look like this:

```
name,email
Alice,alice@example.com
Bob,bob@example.com
```

DataFlow assumes the first row is a header by default. If your CSV doesn't have headers, specify that in the request:

```swift
CSVRequest(path: "data", hasHeader: false)
```

### Important: String Types

CSV values are always parsed as strings, so your Decodable model must accept string types:

```swift
struct Item: Decodable {
    let name: String      // ✅ Works
    let quantity: String  // ✅ Works (stored as string)
    let price: Double     // ❌ Will fail to decode
}
```

If you need numeric types, implement custom decoding:

```swift
struct Item: Decodable {
    let name: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case name, quantity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)

        let quantityString = try container.decode(String.self, forKey: .quantity)
        quantity = Int(quantityString) ?? 0
    }
}
```

### Quoted Fields

CSV fields can contain commas if they're quoted:

```
name,description
"Item 1","A great item, with comma"
"Item 2","Another item, also great"
```

DataFlow handles this automatically—no extra configuration needed.

---

## Real-time Data

DataFlow supports WebSocket connections for streaming real-time data.

### Basic WebSocket

```swift
struct Message: Decodable {
    let id: String
    let text: String
}

let pipeline = WebSocketPipeline<Message>(
    request: WebSocketRequest(
        url: URL(string: "wss://example.com/stream")!
    ),
    source: DataSource<WebSocketRequest>.liveWebSocket()
)

let message = try await pipeline.loadData()
```

### Custom Headers

Add authentication headers for secure WebSocket connections:

```swift
let request = WebSocketRequest(
    url: wsURL,
    headers: [
        "Authorization": "Bearer \(token)",
        "X-Custom-Header": "value"
    ]
)
```

### Note on Streaming

The current WebSocket pipeline loads a single message. For applications that need to stream multiple messages, consider building a custom `StreamingProvider` protocol or using DataFlow's extension points to implement your own WebSocket handler.

---

## Caching

Caching is a powerful way to improve performance by avoiding redundant data fetches. DataFlow makes caching a first-class feature.

### Adding Caching to Any Pipeline

Wrap any pipeline with `CachedPipeline` to add transparent caching:

```swift
let restPipeline = RESTPipeline<User>(
    request: RESTRequest(path: "/users/1"),
    source: .liveAPI(baseUrl: url, authProvider: .none)
)

let cachedPipeline = CachedPipeline(wrapping: restPipeline, ttl: 300)

// First call fetches from network
let user1 = try await cachedPipeline.loadData()

// Subsequent calls within 5 minutes return cached value
let user2 = try await cachedPipeline.loadData()
```

### Time-To-Live (TTL)

Control how long cached values persist:

```swift
// No expiration (cache forever)
CachedPipeline(wrapping: pipeline, ttl: nil)

// 5 minutes
CachedPipeline(wrapping: pipeline, ttl: 300)

// 1 hour
CachedPipeline(wrapping: pipeline, ttl: 3600)
```

### How Caching Works

The cache key is derived from the request. For caching to work, your request type must conform to `Hashable`:

```swift
struct RESTRequest: Hashable, Sendable {
    // ...
}
```

If you need caching for a non-Hashable request type, use `TypedCachedPipeline` with custom string keys:

```swift
let cached = TypedCachedPipeline(
    wrapping: pipeline,
    cacheKey: { "user-\(pipeline.request.id)" },
    ttl: 300
)
```

### Thread-Safe Caching

The caching system uses Swift actors to ensure thread safety. You can safely access cached pipelines from concurrent tasks:

```swift
async let user1 = cachedPipeline.loadData()
async let user2 = cachedPipeline.loadData()

let (u1, u2) = try await (user1, user2)
// Both will return the same cached value if the cache hasn't expired
```

---

## Custom Pipelines

While DataFlow provides implementations for common scenarios, you can easily create custom pipelines for domain-specific needs.

### Anatomy of a Pipeline

A complete pipeline implementation is straightforward:

```swift
// 1. Define your request type
struct DatabaseRequest: Sendable, Hashable {
    let query: String
    let parameters: [String: Any]
}

// 2. Define your transformer (usually just JSON decoding)
struct DatabaseTransformer<Model: Decodable>: DataTransformer {
    func transform(_ data: Data) throws -> Model {
        try JSONDecoder().decode(Model.self, from: data)
    }
}

// 3. Implement your pipeline
struct DatabasePipeline<D: Decodable>: ModelProvider {
    let request: DatabaseRequest
    var source: DataSource<DatabaseRequest>
    var transformer: DatabaseTransformer<D>

    init(request: DatabaseRequest, source: DataSource<DatabaseRequest>) {
        self.request = request
        self.source = source
        self.transformer = DatabaseTransformer<D>()
    }

    func loadData() async throws -> D {
        let data = try await source.fetch(request)
        return try transformer.transform(data)
    }
}

// 4. Optionally, provide factory methods for data sources
extension DataSource where Type == DatabaseRequest {
    static func liveDatabase(_ connection: Database) -> Self {
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
        parameters: [:]
    ),
    source: .liveDatabase(connection: db)
)

let user = try await pipeline.loadData()
```

That's all there is to it. Your custom pipeline immediately gets all the DataFlow benefits: type safety, composability, caching support, and testability.

---

## Combining Pipelines

One of DataFlow's strengths is composability. You can combine pipelines in various ways to build complex data flows.

### Sequential Fetching

Load data from multiple sources sequentially:

```swift
async let user = userPipeline.loadData()
async let posts = postsPipeline.loadData()
async let comments = commentsPipeline.loadData()

let (u, p, c) = try await (user, posts, comments)

struct UserData {
    let user: User
    let posts: [Post]
    let comments: [Comment]
}

let fullData = UserData(user: u, posts: p, comments: c)
```

### Fallback Pattern

Try one pipeline, fall back to another on failure:

```swift
func loadUserWithFallback(id: Int) async throws -> User {
    let restPipeline = RESTPipeline<User>(
        request: RESTRequest(path: "/users/\(id)"),
        source: .liveAPI(baseUrl: apiURL, authProvider: .none)
    )

    do {
        return try await restPipeline.loadData()
    } catch {
        // Network error, try loading from cached version
        let cachedPipeline = FileSystemPipeline<User>(
            request: FileSystemRequest(path: "user_\(id)"),
            source: .fromBundle()
        )
        return try await cachedPipeline.loadData()
    }
}
```

### Aggregating Multiple Requests

Combine results from multiple sources:

```swift
let requests = [
    RESTRequest(path: "/users/1"),
    RESTRequest(path: "/users/2"),
    RESTRequest(path: "/users/3")
]

let aggregation = AggregationRequest(
    identifier: "users-batch",
    subRequests: requests
)

let pipeline = DataAggregationPipeline(
    request: aggregation,
    source: .aggregating(pipelines: [restSource], parallelFetch: true)
)

let combinedResults = try await pipeline.loadData()
```

---

## Error Handling

DataFlow provides specific error types for each implementation, making error handling precise and predictable.

### REST Errors

```swift
do {
    let user = try await restPipeline.loadData()
} catch let error as HTTPError {
    switch error {
    case .badStatus(let code, let data):
        // Handle HTTP errors
        print("HTTP \(code)")
    case .invalidResponse:
        // Handle malformed responses
        print("Invalid response from server")
    }
}
```

### File System Errors

```swift
do {
    let config = try await fileSystemPipeline.loadData()
} catch let error as FileSystemError {
    switch error {
    case .fileNotFound(let path):
        print("File not found: \(path)")
    case .readFailed(let path, let description):
        print("Failed to read \(path): \(description)")
    case .decodingFailed(let description):
        print("Failed to decode: \(description)")
    case .rawFormatRequiresManualDecoding:
        // Handle raw format case
        break
    }
}
```

### CSV Errors

```swift
do {
    let data = try await csvPipeline.loadData()
} catch let error as CSVError {
    switch error {
    case .decodingFailed(let description):
        print("Failed to decode CSV: \(description)")
    case .mismatchedColumns(let row, let expected, let got):
        print("Row \(row) has \(got) columns, expected \(expected)")
    case .modelDecodingFailed(let description):
        print("Model decoding failed: \(description)")
    }
}
```

### General Pattern

Always handle errors with specific types when possible:

```swift
do {
    let result = try await pipeline.loadData()
} catch let error as SpecificErrorType {
    // Handle specific error
} catch {
    // Handle unexpected errors
    print("Unexpected error: \(error)")
}
```

---

## Best Practices

### 1. Reuse Sources

Create data sources once and reuse them across multiple pipelines:

```swift
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
```

### 2. Test with Mocks

Always test with mock data sources, never with real network or file system access:

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

### 3. Use Caching Strategically

Cache results that are expensive to fetch but cheap to invalidate. Don't cache results that change frequently:

```swift
// Good candidates for caching
let cachedUserPipeline = CachedPipeline(wrapping: userPipeline, ttl: 300)
let cachedConfigPipeline = CachedPipeline(wrapping: configPipeline, ttl: 3600)

// Usually not worth caching
let liveEventsPipeline = eventsPipeline  // Events change constantly
```

### 4. Handle Errors Explicitly

Never ignore errors, always handle them appropriately:

```swift
// ✅ Good: Specific error handling
do {
    let user = try await pipeline.loadData()
} catch let error as HTTPError {
    // Handle HTTP errors
} catch {
    // Handle other errors
}

// ❌ Avoid: Ignoring errors
try? pipeline.loadData()  // Error silently ignored
```

### 5. Leverage Type Safety

Let the type system guide your implementation:

```swift
// ✅ Type-safe and self-documenting
let pipeline = RESTPipeline<User>(
    request: RESTRequest(path: "/users/1"),
    source: dataSource
)

// ❌ Unclear types
let data = try await source.fetch(someRequest)
```

---

See also: [API Reference](API_REFERENCE.md) for detailed API documentation.
