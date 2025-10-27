import Testing
import Foundation
@testable import DataFlow

// MARK: - Test Models

/// A simple decodable model for testing
struct User: Decodable, Equatable, Sendable {
    let id: Int
    let name: String
    let email: String
}

/// A more complex model with nested structures
struct Post: Decodable, Equatable, Sendable {
    let id: Int
    let title: String
    let content: String
    let author: Author
    let createdAt: Date

    struct Author: Decodable, Equatable, Sendable {
        let id: Int
        let name: String
    }
}

/// A simple encodable model for custom pipeline testing
struct CustomDataModel: Encodable, Equatable, Sendable {
    let title: String
    let value: Int
}

// MARK: - Mock Data Generators

enum MockData {
    static let userJSON = """
    {
        "id": 1,
        "name": "John Doe",
        "email": "john@example.com"
    }
    """.data(using: .utf8)!

    static let usersJSON = """
    [
        {
            "id": 1,
            "name": "John Doe",
            "email": "john@example.com"
        },
        {
            "id": 2,
            "name": "Jane Smith",
            "email": "jane@example.com"
        }
    ]
    """.data(using: .utf8)!

    static let postJSON = """
    {
        "id": 101,
        "title": "Understanding Swift Concurrency",
        "content": "This post explores structured concurrency in Swift.",
        "author": {
            "id": 1,
            "name": "John Doe"
        },
        "createdAt": "2024-01-15T10:30:00Z"
    }
    """.data(using: .utf8)!

    static let invalidJSON = "{ invalid json }".data(using: .utf8)!

    static func customDataJSON(_ value: CustomDataModel) -> Data {
        let encoder = JSONEncoder()
        return try! encoder.encode(value)
    }
}

// MARK: - Test Data Transformers

/// A custom transformer that decodes an array of models
struct ArrayTransformer<Model: Decodable>: DataTransformer {
    func transform(_ data: Data) throws -> [Model] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Model].self, from: data)
    }
}

/// A CSV-like transformer for demonstration of custom formats
struct CSVTransformer: DataTransformer {
    struct Row: Equatable {
        let values: [String]
    }

    func transform(_ data: Data) throws -> [Row] {
        guard let csv = String(data: data, encoding: .utf8) else {
            throw TransformerError.decodingFailed
        }

        return csv
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { line in
                Row(values: line.components(separatedBy: ","))
            }
    }

    enum TransformerError: Error {
        case decodingFailed
    }
}

// MARK: - Custom Pipeline Implementations

/// A simple XML-like custom pipeline for demonstration
struct CustomDataPipeline<D: Decodable>: ModelProvider {
    var source: DataSource<CustomDataRequest>
    var transformer: JSONTransformer<D>

    private let request: CustomDataRequest

    init(request: CustomDataRequest, source: DataSource<CustomDataRequest>) {
        self.request = request
        self.source = source
        self.transformer = JSONTransformer<D>()
    }

    func loadData() async throws -> D {
        let data = try await source.fetch(request)
        return try transformer.transform(data)
    }
}

/// Custom request type for non-REST data sources
struct CustomDataRequest: Sendable {
    let identifier: String
    let parameters: [String: String]
}

/// A file-based data source for testing custom pipelines
struct FileBasedSource {
    static func make(with data: Data) -> DataSource<CustomDataRequest> {
        DataSource { _ in data }
    }
}

/// A database-like pipeline that filters data
struct FilteredDataPipeline<D: Decodable>: ModelProvider {
    var source: DataSource<FilteredDataRequest>
    var transformer: JSONTransformer<D>

    private let request: FilteredDataRequest

    init(request: FilteredDataRequest, source: DataSource<FilteredDataRequest>) {
        self.request = request
        self.source = source
        self.transformer = JSONTransformer<D>()
    }

    func loadData() async throws -> D {
        let data = try await source.fetch(request)
        return try transformer.transform(data)
    }
}

struct FilteredDataRequest: Sendable {
    let filter: String
    let limit: Int?
}

// MARK: - REST Pipeline Tests

@Suite("REST Pipeline")
struct RESTSourceTests {

    @Test("Successfully fetches and decodes a single user")
    func testFetchSingleUser() async throws {
        // Setup
        let mockSource = DataSource<RESTRequest> { _ in MockData.userJSON }
        let pipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: mockSource
        )

        // Execute
        let user = try await pipeline.loadData()

        // Verify
        #expect(user.id == 1)
        #expect(user.name == "John Doe")
        #expect(user.email == "john@example.com")
    }

    @Test("Successfully fetches and decodes multiple users")
    func testFetchMultipleUsers() async throws {
        // Setup
        let mockSource = DataSource<RESTRequest> { _ in MockData.usersJSON }
        let source = mockSource
        let transformer = ArrayTransformer<User>()

        // Create a simple pipeline that uses the array transformer
        let data = try await source.fetch(RESTRequest(path: "/users"))
        let users = try transformer.transform(data)

        // Verify
        #expect(users.count == 2)
        #expect(users[0].name == "John Doe")
        #expect(users[1].name == "Jane Smith")
    }

    @Test("Successfully fetches and decodes complex nested models")
    func testFetchComplexModel() async throws {
        // Setup
        let mockSource = DataSource<RESTRequest> { _ in MockData.postJSON }
        let pipeline = RESTPipeline<Post>(
            request: RESTRequest(path: "/posts/101"),
            source: mockSource
        )

        // Execute
        let post = try await pipeline.loadData()

        // Verify
        #expect(post.id == 101)
        #expect(post.title == "Understanding Swift Concurrency")
        #expect(post.author.name == "John Doe")
        #expect(post.author.id == 1)
    }

    @Test("Handles JSON decoding errors gracefully")
    func testInvalidJSONHandling() async throws {
        // Setup
        let mockSource = DataSource<RESTRequest> { _ in MockData.invalidJSON }
        let pipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: mockSource
        )

        // Execute & Verify
        await #expect(throws: Error.self) {
            try await pipeline.loadData()
        }
    }

    @Test("Constructs proper REST requests with paths")
    func testRESTRequestConstruction() {
        let request = RESTRequest(path: "/api/users/123")
        #expect(request.path == "/api/users/123")
        #expect(request.method == .get)
        #expect(request.body == nil)
    }

    @Test("Constructs REST requests with query parameters")
    func testRESTRequestWithQueryItems() {
        let queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "limit", value: "10")
        ]
        let request = RESTRequest(path: "/users", queryItems: queryItems)

        #expect(request.path == "/users")
        #expect(request.queryItems.count == 2)
        #expect(request.method == .get)
    }

    @Test("Supports different HTTP methods")
    func testRESTRequestHttpMethods() {
        let methods: [RESTRequest.Method] = [.get, .post, .put, .patch, .delete]

        for method in methods {
            let request = RESTRequest(path: "/test", method: method)
            #expect(request.method == method)
        }
    }

    @Test("Constructs REST requests with body data")
    func testRESTRequestWithBody() {
        let bodyData = MockData.customDataJSON(CustomDataModel(title: "Test", value: 42))
        let request = RESTRequest(path: "/data", method: .post, body: bodyData)

        #expect(request.body == bodyData)
        #expect(request.method == .post)
    }

    @Test("Multiple sequential requests use independent data sources")
    func testSequentialRequests() async throws {
        // Setup
        let mockSource = DataSource<RESTRequest> { _ in MockData.userJSON }

        let pipeline1 = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: mockSource
        )
        let pipeline2 = RESTPipeline<User>(
            request: RESTRequest(path: "/users/2"),
            source: mockSource
        )

        // Execute
        let user1 = try await pipeline1.loadData()
        let user2 = try await pipeline2.loadData()

        // Verify
        #expect(user1.name == "John Doe")
        #expect(user2.name == "John Doe")
    }
}

// MARK: - Transformer Tests

@Suite("Data Transformers")
struct DataTransformerTests {

    @Test("JSONTransformer decodes valid JSON to model")
    func testJSONTransformer() throws {
        let transformer = JSONTransformer<User>()
        let user = try transformer.transform(MockData.userJSON)

        #expect(user.id == 1)
        #expect(user.name == "John Doe")
    }

    @Test("ArrayTransformer decodes JSON array to models")
    func testArrayTransformer() throws {
        let transformer = ArrayTransformer<User>()
        let users = try transformer.transform(MockData.usersJSON)

        #expect(users.count == 2)
        #expect(users[0].id == 1)
        #expect(users[1].id == 2)
    }

    @Test("CSVTransformer parses CSV data")
    func testCSVTransformer() throws {
        let csvData = "name,age,city\nJohn,30,NYC\nJane,25,LA".data(using: .utf8)!
        let transformer = CSVTransformer()
        let rows = try transformer.transform(csvData)

        #expect(rows.count == 3)
        #expect(rows[0].values == ["name", "age", "city"])
        #expect(rows[1].values == ["John", "30", "NYC"])
    }

    @Test("Custom transformers implement DataTransformer protocol correctly")
    func testCustomTransformerProtocolConformance() throws {
        let transformer = ArrayTransformer<User>()
        let result = try transformer.transform(MockData.usersJSON)

        #expect(result.count == 2)
    }
}

// MARK: - Custom Pipeline Tests

@Suite("Custom Data Pipelines")
struct CustomPipelineTests {

    @Test("Custom pipeline fetches and transforms data")
    func testCustomPipelineBasic() async throws {
        // Setup
        let source = DataSource<CustomDataRequest> { _ in MockData.userJSON }
        let pipeline = CustomDataPipeline<User>(
            request: CustomDataRequest(identifier: "user-1", parameters: [:]),
            source: source
        )

        // Execute
        let user = try await pipeline.loadData()

        // Verify
        #expect(user.id == 1)
        #expect(user.name == "John Doe")
    }

    @Test("File-based source provides data from stored content")
    func testFileBasedSource() async throws {
        // Setup
        let source = FileBasedSource.make(with: MockData.userJSON)
        let pipeline = CustomDataPipeline<User>(
            request: CustomDataRequest(identifier: "file", parameters: [:]),
            source: source
        )

        // Execute
        let user = try await pipeline.loadData()

        // Verify
        #expect(user.email == "john@example.com")
    }

    @Test("Custom request parameters are passed to source")
    func testCustomRequestParameters() async throws {
        // Create a source that validates the request structure
        let source = DataSource<CustomDataRequest> { request in
            // Verify that the request has the expected structure
            #expect(!request.identifier.isEmpty)
            #expect(request.parameters["filter"] == "active")
            return MockData.userJSON
        }

        let params = ["filter": "active", "sort": "name"]
        let customRequest = CustomDataRequest(
            identifier: "users",
            parameters: params
        )

        // Execute - the expectations inside the source closure will verify the request
        let pipeline = CustomDataPipeline<User>(
            request: customRequest,
            source: source
        )
        let user = try await pipeline.loadData()

        #expect(user.id == 1)
    }

    @Test("Filtered pipeline respects filter and limit parameters")
    func testFilteredPipeline() async throws {
        let source = DataSource<FilteredDataRequest> { request in
            // Simulate filtering behavior
            #expect(request.limit == 10)
            #expect(request.filter == "active")
            return MockData.userJSON
        }

        let pipeline = FilteredDataPipeline<User>(
            request: FilteredDataRequest(filter: "active", limit: 10),
            source: source
        )

        let user = try await pipeline.loadData()
        #expect(user.id == 1)
    }

    @Test("Custom pipelines support different request types")
    func testCustomRequestTypes() async throws {
        // Create a pipeline with String requests
        let stringSource = DataSource<String> { identifier in
            // Simulate looking up data by identifier
            return identifier == "john" ? MockData.userJSON : MockData.usersJSON
        }

        let data = try await stringSource.fetch("john")
        let transformer = JSONTransformer<User>()
        let user = try transformer.transform(data)

        #expect(user.name == "John Doe")
    }

    @Test("Composable transformers enable chaining")
    func testComposableTransformers() throws {
        // First transformation: JSON to array
        let arrayTransformer = ArrayTransformer<User>()
        let users = try arrayTransformer.transform(MockData.usersJSON)

        // Second transformation: filter and count
        let filtered = users.filter { $0.id == 1 }

        #expect(filtered.count == 1)
        #expect(filtered[0].name == "John Doe")
    }
}

// MARK: - Error Handling Tests

@Suite("Error Handling and Edge Cases")
struct ErrorHandlingTests {

    @Test("Pipeline throws on invalid JSON structure")
    func testInvalidJSONThrows() async throws {
        let mockSource = DataSource<RESTRequest> { _ in MockData.invalidJSON }
        let pipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: mockSource
        )

        await #expect(throws: Error.self) {
            try await pipeline.loadData()
        }
    }

    @Test("Data source can throw custom errors")
    func testDataSourceCustomErrors() async throws {
        enum CustomError: Error {
            case networkFailure
            case timeout
        }

        let failingSource = DataSource<RESTRequest> { _ in
            throw CustomError.networkFailure
        }

        let pipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users"),
            source: failingSource
        )

        await #expect(throws: CustomError.self) {
            try await pipeline.loadData()
        }
    }

    @Test("Transformer errors propagate correctly")
    func testTransformerErrorPropagation() async throws {
        let mockSource = DataSource<RESTRequest> { _ in
            "not json".data(using: .utf8)!
        }

        let pipeline = RESTPipeline<Post>(
            request: RESTRequest(path: "/posts/1"),
            source: mockSource
        )

        await #expect(throws: Error.self) {
            try await pipeline.loadData()
        }
    }

    @Test("Empty data handling")
    func testEmptyDataHandling() async throws {
        let emptySource = DataSource<RESTRequest> { _ in Data() }
        let pipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users"),
            source: emptySource
        )

        await #expect(throws: Error.self) {
            try await pipeline.loadData()
        }
    }

    @Test("Handles missing required JSON fields")
    func testMissingRequiredFields() async throws {
        let incompleteJSON = """
        {
            "id": 1,
            "name": "John"
        }
        """.data(using: .utf8)!

        let mockSource = DataSource<RESTRequest> { _ in incompleteJSON }
        let pipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: mockSource
        )

        await #expect(throws: Error.self) {
            try await pipeline.loadData()
        }
    }

    @Test("Concurrent requests maintain isolation")
    func testConcurrentRequests() async throws {
        let source = DataSource<RESTRequest> { _ in MockData.userJSON }

        let pipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: source
        )

        // Run concurrent requests
        async let result1 = pipeline.loadData()
        async let result2 = pipeline.loadData()
        async let result3 = pipeline.loadData()

        let (user1, user2, user3) = try await (result1, result2, result3)

        #expect(user1.id == 1)
        #expect(user2.id == 1)
        #expect(user3.id == 1)
    }
}

// MARK: - Integration Tests

@Suite("Integration Tests")
struct IntegrationTests {

    @Test("Complete pipeline from request to model")
    func testCompletePipeline() async throws {
        // Setup a realistic pipeline
        let mockNetworkSource = DataSource<RESTRequest> { request in
            // Simulate network call
            #expect(request.path == "/api/users/1")
            return MockData.userJSON
        }

        let pipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/api/users/1"),
            source: mockNetworkSource
        )

        // Execute
        let user = try await pipeline.loadData()

        // Verify
        #expect(user.id == 1)
        #expect(user.name == "John Doe")
        #expect(user.email == "john@example.com")
    }

    @Test("Mixed pipeline types working together")
    func testMixedPipelineTypes() async throws {
        // REST pipeline
        let restSource = DataSource<RESTRequest> { _ in MockData.userJSON }
        let restPipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: restSource
        )

        // Custom pipeline
        let customSource = DataSource<CustomDataRequest> { _ in MockData.userJSON }
        let customPipeline = CustomDataPipeline<User>(
            request: CustomDataRequest(identifier: "cache", parameters: [:]),
            source: customSource
        )

        // Execute both
        let restUser = try await restPipeline.loadData()
        let customUser = try await customPipeline.loadData()

        // Verify they produce same results
        #expect(restUser == customUser)
    }

    @Test("Sequential data loading from multiple sources")
    func testSequentialDataLoading() async throws {
        let userSource = DataSource<RESTRequest> { _ in MockData.userJSON }
        let postSource = DataSource<RESTRequest> { _ in MockData.postJSON }

        let userPipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: userSource
        )

        let postPipeline = RESTPipeline<Post>(
            request: RESTRequest(path: "/posts/101"),
            source: postSource
        )

        let user = try await userPipeline.loadData()
        let post = try await postPipeline.loadData()

        #expect(user.id == 1)
        #expect(post.author.name == "John Doe")
    }
}
