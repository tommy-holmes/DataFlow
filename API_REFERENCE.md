# DataFlow API Reference

Complete API documentation for the DataFlow library.

## Table of Contents

1. [Core Protocols](#core-protocols)
2. [Request Types](#request-types)
3. [Transformers](#transformers)
4. [Pipelines](#pipelines)
5. [Data Sources](#data-sources)
6. [Error Types](#error-types)

---

## Core Protocols

### DataSource

```swift
public struct DataSource<Type>: Sendable {
    public typealias FetchFunction = @Sendable (Type) async throws -> Data

    public var fetch: FetchFunction

    public init(fetch: @escaping FetchFunction)
}
```

A `DataSource` encapsulates the logic for fetching raw `Data` from any source. It's a simple closure-based type that works with any async data provider.

**Generic Parameter**:
- `Type`: The request type this source accepts

**Methods**:
- `init(fetch:)`: Initialize with a fetch function
- `fetch(_:)`: Fetch raw data for a request

**Example**:
```swift
let source = DataSource<RESTRequest> { request in
    // Perform network request
    return try await URLSession.shared.data(for: request)
}
```

---

### DataTransformer

```swift
public protocol DataTransformer: Sendable {
    associatedtype Input
    associatedtype Output

    func transform(_ data: Input) throws -> Output
}
```

A `DataTransformer` converts raw input data into strongly-typed output. Implementations typically use `JSONDecoder`, `PropertyListDecoder`, or custom parsing.

**Associated Types**:
- `Input`: Type of raw data to transform (usually `Data`)
- `Output`: Type of transformed result

**Methods**:
- `transform(_:)`: Transform input to output

**Implementations**:
- `JSONTransformer<Model>`: Decodes JSON to Decodable model
- `FileSystemTransformer<Model>`: Handles JSON/PropertyList formats
- `CSVTransformer<Model>`: Parses CSV data
- `WebSocketTransformer<Model>`: Decodes WebSocket messages
- `AggregationTransformer`: Passthrough aggregation data

---

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

A `ModelProvider` orchestrates a data source and transformer to provide a complete pipeline for fetching and decoding data.

**Associated Types**:
- `Model`: The strongly-typed output model
- `Transformer`: The DataTransformer implementation
- `Request`: The request type this pipeline accepts

**Properties**:
- `request`: The request to be executed
- `source`: The data source for fetching
- `transformer`: The transformer for decoding

**Methods**:
- `loadData()`: Execute the pipeline, returning decoded model

**Implementations**:
- `RESTPipeline<D>`: REST API pipelines
- `CSVPipeline<D>`: CSV file parsing
- `FileSystemPipeline<D>`: File system loading
- `WebSocketPipeline<D>`: WebSocket streaming
- `DataAggregationPipeline<SubRequest>`: Multi-source aggregation
- `CachedPipeline<Provider>`: Caching wrapper
- `TypedCachedPipeline<Provider>`: Alternative caching wrapper

---

## Request Types

### RESTRequest

```swift
public struct RESTRequest: Sendable, Hashable {
    public enum Method: String, Sendable {
        case get, post, put, patch, delete
    }

    public let path: String
    public let queryItems: [URLQueryItem]
    public let method: Method
    public let body: Data?

    public init(
        path: String,
        method: Method = .get,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    )
}
```

Represents an HTTP request to a REST API.

**Properties**:
- `path`: API endpoint path (e.g., "/users/1")
- `queryItems`: URL query parameters
- `method`: HTTP method (.get, .post, .put, .patch, .delete)
- `body`: Optional request body data

**Conformance**:
- `Sendable`: Safe to use across task boundaries
- `Hashable`: Can be used as cache key

**Example**:
```swift
RESTRequest(
    path: "/users",
    method: .get,
    queryItems: [URLQueryItem(name: "page", value: "1")]
)
```

---

### CSVRequest

```swift
public struct CSVRequest: Sendable {
    public let path: String

    public init(path: String)
}
```

Represents a CSV file to load.

**Properties**:
- `path`: File path or identifier (e.g., "users")

**Example**:
```swift
CSVRequest(path: "users")
```

---

### FileSystemRequest

```swift
public struct FileSystemRequest: Sendable {
    public enum Format: Sendable {
        case json
        case propertyList
    }

    public let path: String
    public let bundle: Bundle
    public let format: Format

    public init(
        path: String,
        bundle: Bundle = .main,
        format: Format = .json
    )
}
```

Represents a file to load from the file system.

**Properties**:
- `path`: File path without extension (e.g., "config")
- `bundle`: Bundle to load from (default: .main)
- `format`: File format (.json or .propertyList)

**Example**:
```swift
FileSystemRequest(path: "config", bundle: .main, format: .json)
```

---

### WebSocketRequest

```swift
public struct WebSocketRequest: Sendable {
    public let url: URL
    public let headers: [String: String]
    public let messageCount: Int?

    public init(
        url: URL,
        headers: [String: String] = [:],
        messageCount: Int? = nil
    )
}
```

Represents a WebSocket connection.

**Properties**:
- `url`: WebSocket URL (e.g., "wss://example.com/stream")
- `headers`: Custom HTTP headers for connection
- `messageCount`: Limit number of messages (nil = unlimited)

**Example**:
```swift
WebSocketRequest(
    url: URL(string: "wss://example.com/stream")!,
    headers: ["Authorization": "Bearer token"],
    messageCount: 1
)
```

---

### AggregationRequest

```swift
public struct AggregationRequest<T: Sendable>: Sendable {
    public let identifier: String
    public let subRequests: [T]

    public init(identifier: String, subRequests: [T])
}
```

Represents a batch of sub-requests to aggregate.

**Generic Parameter**:
- `T`: Type of sub-requests

**Properties**:
- `identifier`: Name for this aggregation batch
- `subRequests`: Array of sub-requests to fetch

**Example**:
```swift
AggregationRequest(
    identifier: "batch-1",
    subRequests: [
        RESTRequest(path: "/users/1"),
        RESTRequest(path: "/users/2")
    ]
)
```

---

## Transformers

### JSONTransformer

```swift
public struct JSONTransformer<Model: Decodable>: DataTransformer {
    public init()
}
```

Decodes JSON Data into a Decodable model.

**Generic Parameter**:
- `Model`: Decodable model type

**Features**:
- ISO8601 date decoding
- Standard JSONDecoder configuration

**Example**:
```swift
let transformer = JSONTransformer<User>()
let user = try transformer.transform(jsonData)
```

---

### CSVTransformer

```swift
public struct CSVTransformer<Model: Decodable>: DataTransformer {
    public enum CSVHeaderConfiguration: Sendable {
        case fromCSV
        case custom([String])
    }

    public init(headerConfiguation: CSVHeaderConfiguration)
}
```

Parses CSV data and decodes rows into models.

**Generic Parameter**:
- `Model`: Decodable model type

**Header Configuration**:
- `.fromCSV`: Use the first line of the CSV as headers
- `.custom([String])`: Provide custom headers (first line is data)
- `.custom([])`: Generate generic headers (column_0, column_1, etc.)

**Features**:
- CSV parsing with quoted field support
- Column count validation
- Flexible header handling

**Limitations**:
- CSV values are parsed as strings
- Models must accept String fields or custom decoders

**Example**:
```swift
// Use headers from CSV file
let transformer = CSVTransformer<Person>(headerConfiguation: .fromCSV)
let people = try transformer.transform(csvData)

// Provide custom headers
let transformer = CSVTransformer<Person>(
    headerConfiguation: .custom(["name", "email"])
)
let people = try transformer.transform(csvData)
```

---

### FileSystemTransformer

```swift
public struct FileSystemTransformer<Model: Decodable>: DataTransformer {
    public init(format: FileSystemRequest.Format = .json)
}
```

Decodes file data into a model based on format.

**Generic Parameter**:
- `Model`: Decodable model type

**Parameters**:
- `format`: File format (.json or .propertyList)

**Example**:
```swift
let transformer = FileSystemTransformer<Config>(format: .json)
let config = try transformer.transform(fileData)
```

---

### WebSocketTransformer

```swift
public struct WebSocketTransformer<Model: Decodable>: DataTransformer {
    public init()
}
```

Decodes WebSocket message data into a model.

**Generic Parameter**:
- `Model`: Decodable model type

**Example**:
```swift
let transformer = WebSocketTransformer<Message>()
let message = try transformer.transform(messageData)
```

---

### AggregationTransformer

```swift
public struct AggregationTransformer: DataTransformer {
    public init()
}
```

Passthrough transformer for aggregated data.

**Note**: Returns data unchanged - designed for intermediate processing.

---

## Pipelines

### RESTPipeline

```swift
public struct RESTPipeline<D: Decodable>: ModelProvider {
    public let request: RESTRequest
    public var source: DataSource<RESTRequest>
    public var transformer: JSONTransformer<D>

    public init(
        request: RESTRequest,
        source: DataSource<RESTRequest>
    )

    public func loadData() async throws -> D
}
```

Fetches data from REST API and decodes into model.

**Generic Parameter**:
- `D`: Decodable model type

**Properties**:
- `request`: RESTRequest specifying endpoint
- `source`: Data source for network requests
- `transformer`: JSON decoder

**Methods**:
- `init(request:source:)`: Initialize pipeline
- `loadData()`: Fetch and decode

**Example**:
```swift
let pipeline = RESTPipeline<User>(
    request: RESTRequest(path: "/users/1"),
    source: .liveAPI(baseUrl: url, authProvider: .none)
)

let user = try await pipeline.loadData()
```

---

### CSVPipeline

```swift
public struct CSVPipeline<D: Decodable>: ModelProvider {
    public let request: CSVRequest
    public var source: DataSource<CSVRequest>
    public var transformer: CSVTransformer<D>

    public init(
        request: CSVRequest,
        source: DataSource<CSVRequest>,
        headerConfiguation: CSVTransformer<D>.CSVHeaderConfiguration = .fromCSV
    )

    public func loadData() async throws -> [D]
}
```

Parses CSV data into array of models.

**Generic Parameter**:
- `D`: Decodable model type

**Parameters**:
- `request`: CSVRequest specifying data location
- `source`: Data source for fetching CSV data
- `headerConfiguation`: How to handle CSV headers (default: .fromCSV)

**Returns**: Array of decoded models

**Header Configuration**:
- `.fromCSV`: Use the first line of the CSV as headers
- `.custom([String])`: Provide custom headers (assumes no header row in CSV)
- `.custom([])`: Auto-generate column names (column_0, column_1, etc.)

**Example**:
```swift
// Load CSV with headers from file
let pipeline = CSVPipeline<Person>(
    request: CSVRequest(path: "people"),
    source: .from(bundle: .main)
)

// Load CSV with custom headers (no header row in file)
let pipeline = CSVPipeline<Person>(
    request: CSVRequest(path: "people"),
    source: .from(csvData: csvData),
    headerConfiguation: .custom(["name", "email", "age"])
)

let people = try await pipeline.loadData()
```

---

### FileSystemPipeline

```swift
public struct FileSystemPipeline<D: Decodable>: ModelProvider {
    public let request: FileSystemRequest
    public var source: DataSource<FileSystemRequest>
    public var transformer: FileSystemTransformer<D>

    public init(
        request: FileSystemRequest,
        source: DataSource<FileSystemRequest>
    )

    public func loadData() async throws -> D
}
```

Loads file from bundle or file system into model.

**Generic Parameter**:
- `D`: Decodable model type

**Example**:
```swift
let pipeline = FileSystemPipeline<Config>(
    request: FileSystemRequest(path: "config", format: .json),
    source: .fromBundle()
)

let config = try await pipeline.loadData()
```

---

### WebSocketPipeline

```swift
public struct WebSocketPipeline<D: Decodable>: ModelProvider {
    public let request: WebSocketRequest
    public var source: DataSource<WebSocketRequest>
    public var transformer: WebSocketTransformer<D>

    public init(
        request: WebSocketRequest,
        source: DataSource<WebSocketRequest>
    )

    public func loadData() async throws -> D
}
```

Connects to WebSocket and loads first message.

**Generic Parameter**:
- `D`: Decodable model type

**Example**:
```swift
let pipeline = WebSocketPipeline<Message>(
    request: WebSocketRequest(url: wsURL),
    source: .liveWebSocket()
)

let message = try await pipeline.loadData()
```

---

### DataAggregationPipeline

```swift
public struct DataAggregationPipeline<SubRequest: Sendable>: ModelProvider {
    public let request: AggregationRequest<SubRequest>
    public var source: DataSource<AggregationRequest<SubRequest>>
    public var transformer: AggregationTransformer

    public init(
        request: AggregationRequest<SubRequest>,
        source: DataSource<AggregationRequest<SubRequest>>
    )

    public func loadData() async throws -> Data
}
```

Aggregates results from multiple sub-requests.

**Generic Parameter**:
- `SubRequest`: Type of sub-requests

**Returns**: Combined Data from all requests

**Example**:
```swift
let aggregation = AggregationRequest(
    identifier: "batch",
    subRequests: [
        RESTRequest(path: "/users/1"),
        RESTRequest(path: "/users/2")
    ]
)

let pipeline = DataAggregationPipeline(
    request: aggregation,
    source: .aggregating(pipelines: [restSource])
)

let results = try await pipeline.loadData()
```

---

### CachedPipeline

```swift
public struct CachedPipeline<Provider: ModelProvider>: ModelProvider
where Provider.Request: Hashable & Sendable, Provider.Model: Sendable {
    public let wrapped: Provider
    public var request: Provider.Request
    public var source: DataSource<Provider.Request>
    public var transformer: Provider.Transformer

    public init(
        wrapping wrapped: Provider,
        ttl: TimeInterval? = nil
    )

    public func loadData() async throws -> Provider.Model
}
```

Caches pipeline results with optional TTL.

**Generic Parameter**:
- `Provider`: ModelProvider to wrap

**Constraint**: Request must be Hashable

**Parameters**:
- `wrapped`: Pipeline to cache
- `ttl`: Time-to-live in seconds (nil = no expiration)

**Example**:
```swift
let cached = CachedPipeline(wrapping: pipeline, ttl: 300)

let user1 = try await cached.loadData()  // Fetches
let user2 = try await cached.loadData()  // Cached
```

---

### TypedCachedPipeline

```swift
public struct TypedCachedPipeline<Provider: ModelProvider>: ModelProvider
where Provider.Model: Sendable {
    public let wrapped: Provider
    public var request: Provider.Request
    public var source: DataSource<Provider.Request>
    public var transformer: Provider.Transformer

    public init(
        wrapping provider: Provider,
        cacheKey: @escaping @Sendable () -> String,
        ttl: TimeInterval? = nil
    )

    public func loadData() async throws -> Provider.Model
}
```

Caches using custom string keys instead of request.

**Generic Parameter**:
- `Provider`: ModelProvider to wrap

**Parameters**:
- `provider`: Pipeline to cache
- `cacheKey`: Function returning cache key string
- `ttl`: Time-to-live in seconds

**Example**:
```swift
let cached = TypedCachedPipeline(
    wrapping: pipeline,
    cacheKey: { "user-\(pipeline.request.id)" },
    ttl: 300
)

let user = try await cached.loadData()
```

---

## Data Sources

### Common Extensions

#### RESTRequest DataSource

```swift
public extension DataSource where Type == RESTRequest {
    static func liveAPI(
        baseUrl: URL,
        authProvider: AuthProvider = .none
    ) -> Self
}
```

Creates a live REST API data source.

**Parameters**:
- `baseUrl`: Base URL for API requests
- `authProvider`: Authentication strategy

**Auth Providers**:
- `.none`: No authentication
- `.bearerToken(String)`: Bearer token auth
- `.jwtProvider(JWTProvider)`: JWT with refresh support

---

#### CSVRequest DataSource

```swift
public extension DataSource where Type == CSVRequest {
    static func from(bundle: Bundle = .main) -> Self
    static func from(csvData: Data) -> Self
}
```

Creates data sources for CSV data.

**Methods**:
- `from(bundle:)`: Load CSV files from app bundle (default: .main)
- `from(csvData:)`: Use raw CSV data directly

**Example**:
```swift
// Load from bundle
let source = DataSource<CSVRequest>.from(bundle: .main)

// Use raw data
let csvData = "name,email\nAlice,alice@example.com".data(using: .utf8)!
let source = DataSource<CSVRequest>.from(csvData: csvData)
```

---

#### FileSystemRequest DataSource

```swift
public extension DataSource where Type == FileSystemRequest {
    static func fromBundle() -> Self
    static func fromFileManager(at path: String) -> Self
}
```

Creates file system data sources.

**Methods**:
- `fromBundle()`: Load from app bundle
- `fromFileManager(at:)`: Load from specific directory

---

#### WebSocketRequest DataSource

```swift
public extension DataSource where Type == WebSocketRequest {
    static func liveWebSocket() -> Self
}
```

Creates a live WebSocket data source.

---

#### AggregationRequest DataSource

```swift
public extension DataSource {
    static func aggregating<SubRequest>(
        pipelines: [DataSource<SubRequest>],
        parallelFetch: Bool = true
    ) -> DataSource<AggregationRequest<SubRequest>>
}
```

Creates an aggregating data source.

**Parameters**:
- `pipelines`: Array of data sources for sub-requests
- `parallelFetch`: Execute concurrently if true (default: true)

---

## Error Types

### HTTPError

```swift
public enum HTTPError: Error {
    case badStatus(code: Int, data: Data?)
    case invalidResponse
}
```

HTTP-related errors from REST pipelines.

---

### CSVError

```swift
public enum CSVError: Error, Sendable {
    case decodingFailed(String)
    case mismatchedColumns(row: Int, expected: Int, got: Int)
    case modelDecodingFailed(String)
}
```

CSV parsing and decoding errors.

---

### CSVSourceError

```swift
public enum CSVSourceError: Error, Sendable {
    case fileNotFound(String)
    case readFailed(path: String, description: String)
}
```

CSV file loading errors.

---

### FileSystemError

```swift
public enum FileSystemError: Error, Sendable {
    case fileNotFound(String)
    case readFailed(path: String, description: String)
    case decodingFailed(description: String)
    case rawFormatRequiresManualDecoding
}
```

File system loading and decoding errors.

---

### WebSocketError

```swift
public enum WebSocketError: Error, Sendable {
    case connectionFailed(Error)
    case noDataReceived
    case invalidURL
}
```

WebSocket connection errors.

---

## Usage Quick Reference

### Simple REST API Call

```swift
let pipeline = RESTPipeline<User>(
    request: RESTRequest(path: "/users/1"),
    source: .liveAPI(baseUrl: apiURL, authProvider: .bearerToken(token))
)

let user = try await pipeline.loadData()
```

### Load from Bundle

```swift
let pipeline = FileSystemPipeline<Config>(
    request: FileSystemRequest(path: "config"),
    source: .fromBundle()
)

let config = try await pipeline.loadData()
```

### With Caching

```swift
let cached = CachedPipeline(wrapping: pipeline, ttl: 300)
let user = try await cached.loadData()
```

### Error Handling

```swift
do {
    let user = try await pipeline.loadData()
} catch let error as HTTPError {
    print("HTTP error: \(error)")
} catch {
    print("Other error: \(error)")
}
```

---

## Thread Safety Notes

All types are `Sendable` and safe to use across task boundaries:

```swift
async let user1 = pipeline.loadData()
async let user2 = pipeline.loadData()

let (u1, u2) = try await (user1, user2)
```

Caching is actor-based and thread-safe:

```swift
let cached = CachedPipeline(wrapping: pipeline, ttl: 300)

await cached.loadData()  // Safe concurrent access
```

---

End of API Reference
