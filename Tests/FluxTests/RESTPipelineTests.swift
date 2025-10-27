import Testing
import Foundation
@testable import Flux

// MARK: - REST Pipeline Tests

@Suite("REST Pipeline")
struct RESTPipelineTests {

    // MARK: Basic Fetching Tests

    @Test("Successfully fetches and decodes a single user")
    func fetchSingleUser() async throws {
        let mockSource = DataSource<RESTRequest> { _ in MockDataFixtures.userJSON }
        let pipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: mockSource
        )

        let user = try await pipeline.loadData()

        #expect(user.id == 1)
        #expect(user.name == "John Doe")
        #expect(user.email == "john@example.com")
    }

    @Test("Successfully fetches and decodes multiple users")
    func fetchMultipleUsers() async throws {
        let mockSource = DataSource<RESTRequest> { _ in MockDataFixtures.usersJSON }
        let transformer = ArrayTransformer<User>()

        let data = try await mockSource.fetch(RESTRequest(path: "/users"))
        let users = try transformer.transform(data)

        #expect(users.count == 2)
        #expect(users[0].name == "John Doe")
        #expect(users[1].name == "Jane Smith")
    }

    @Test("Successfully fetches and decodes complex nested models")
    func fetchComplexModel() async throws {
        let mockSource = DataSource<RESTRequest> { _ in MockDataFixtures.postJSON }
        let pipeline = RESTPipeline<Post>(
            request: RESTRequest(path: "/posts/101"),
            source: mockSource
        )

        let post = try await pipeline.loadData()

        #expect(post.id == 101)
        #expect(post.title == "Understanding Swift Concurrency")
        #expect(post.author.name == "John Doe")
        #expect(post.author.id == 1)
    }

    // MARK: Request Construction Tests

    @Test("Constructs proper REST requests with paths")
    func constructRESTRequestWithPath() {
        let request = RESTRequest(path: "/api/users/123")

        #expect(request.path == "/api/users/123")
        #expect(request.method == .get)
        #expect(request.body == nil)
    }

    @Test("Constructs REST requests with query parameters")
    func constructRESTRequestWithQueryItems() {
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
    func supportHTTPMethods() {
        let methods: [RESTRequest.Method] = [.get, .post, .put, .patch, .delete]

        for method in methods {
            let request = RESTRequest(path: "/test", method: method)
            #expect(request.method == method)
        }
    }

    @Test("Constructs REST requests with body data")
    func constructRESTRequestWithBody() {
        let bodyData = MockDataFixtures.customDataJSON(CustomDataModel(title: "Test", value: 42))
        let request = RESTRequest(path: "/data", method: .post, body: bodyData)

        #expect(request.body == bodyData)
        #expect(request.method == .post)
    }

    // MARK: Sequential and Concurrent Request Tests

    @Test("Multiple sequential requests use independent data sources")
    func sequentialRequests() async throws {
        let mockSource = DataSource<RESTRequest> { _ in MockDataFixtures.userJSON }

        let pipeline1 = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: mockSource
        )
        let pipeline2 = RESTPipeline<User>(
            request: RESTRequest(path: "/users/2"),
            source: mockSource
        )

        let user1 = try await pipeline1.loadData()
        let user2 = try await pipeline2.loadData()

        #expect(user1.name == "John Doe")
        #expect(user2.name == "John Doe")
    }

    @Test("Concurrent requests maintain isolation")
    func concurrentRequests() async throws {
        let source = DataSource<RESTRequest> { _ in MockDataFixtures.userJSON }

        let pipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: source
        )

        async let result1 = pipeline.loadData()
        async let result2 = pipeline.loadData()
        async let result3 = pipeline.loadData()

        let (user1, user2, user3) = try await (result1, result2, result3)

        #expect(user1.id == 1)
        #expect(user2.id == 1)
        #expect(user3.id == 1)
    }
}

// MARK: - Data Transformer Tests

@Suite("Data Transformers")
struct DataTransformerTests {

    @Test("JSONTransformer decodes valid JSON to model")
    func jsonTransformerDecodesModel() throws {
        let transformer = JSONTransformer<User>()
        let user = try transformer.transform(MockDataFixtures.userJSON)

        #expect(user.id == 1)
        #expect(user.name == "John Doe")
    }

    @Test("ArrayTransformer decodes JSON array to models")
    func arrayTransformerDecodesArray() throws {
        let transformer = ArrayTransformer<User>()
        let users = try transformer.transform(MockDataFixtures.usersJSON)

        #expect(users.count == 2)
        #expect(users[0].id == 1)
        #expect(users[1].id == 2)
    }

    @Test("CSVTransformer parses CSV data")
    func csvTransformerParsesData() throws {
        let csvData = "name,age,city\nJohn,30,NYC\nJane,25,LA".data(using: .utf8)!
        let transformer = CSVTransformer()
        let rows = try transformer.transform(csvData)

        #expect(rows.count == 3)
        #expect(rows[0].values == ["name", "age", "city"])
        #expect(rows[1].values == ["John", "30", "NYC"])
    }

    @Test("Custom transformers implement DataTransformer protocol correctly")
    func customTransformerProtocolConformance() throws {
        let transformer = ArrayTransformer<User>()
        let result = try transformer.transform(MockDataFixtures.usersJSON)

        #expect(result.count == 2)
    }
}

// MARK: - REST Error Handling Tests

@Suite("REST Error Handling")
struct RESTErrorHandlingTests {

    @Test("Pipeline throws on invalid JSON structure")
    func invalidJSONThrows() async throws {
        let mockSource = DataSource<RESTRequest> { _ in MockDataFixtures.invalidJSON }
        let pipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: mockSource
        )

        await #expect(throws: Error.self) {
            try await pipeline.loadData()
        }
    }

    @Test("Handles JSON decoding errors gracefully")
    func handleJSONDecodingErrors() async throws {
        let mockSource = DataSource<RESTRequest> { _ in MockDataFixtures.invalidJSON }
        let pipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: mockSource
        )

        await #expect(throws: Error.self) {
            try await pipeline.loadData()
        }
    }

    @Test("Data source can throw custom errors")
    func dataSourceCustomErrors() async throws {
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
    func transformerErrorPropagation() async throws {
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
    func emptyDataHandling() async throws {
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
    func missingRequiredFields() async throws {
        let mockSource = DataSource<RESTRequest> { _ in MockDataFixtures.incompleteJSON }
        let pipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: mockSource
        )

        await #expect(throws: Error.self) {
            try await pipeline.loadData()
        }
    }
}
