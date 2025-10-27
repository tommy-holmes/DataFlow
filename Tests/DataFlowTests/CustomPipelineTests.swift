import Testing
import Foundation
@testable import DataFlow

// MARK: - Custom Pipeline Tests

@Suite("Custom Data Pipelines")
struct CustomPipelineTests {

    // MARK: Basic Custom Pipeline Tests

    @Test("Custom pipeline fetches and transforms data")
    func customPipelineBasic() async throws {
        let source = DataSource<CustomDataRequest> { _ in MockDataFixtures.userJSON }
        let pipeline = CustomDataPipeline<User>(
            request: CustomDataRequest(identifier: "user-1", parameters: [:]),
            source: source
        )

        let user = try await pipeline.loadData()

        #expect(user.id == 1)
        #expect(user.name == "John Doe")
    }

    @Test("File-based source provides data from stored content")
    func fileBasedSource() async throws {
        let source = FileBasedSource.make(with: MockDataFixtures.userJSON)
        let pipeline = CustomDataPipeline<User>(
            request: CustomDataRequest(identifier: "file", parameters: [:]),
            source: source
        )

        let user = try await pipeline.loadData()

        #expect(user.email == "john@example.com")
    }

    @Test("Custom request parameters are passed to source")
    func customRequestParameters() async throws {
        let source = DataSource<CustomDataRequest> { request in
            #expect(!request.identifier.isEmpty)
            #expect(request.parameters["filter"] == "active")
            return MockDataFixtures.userJSON
        }

        let params = ["filter": "active", "sort": "name"]
        let customRequest = CustomDataRequest(
            identifier: "users",
            parameters: params
        )

        let pipeline = CustomDataPipeline<User>(
            request: customRequest,
            source: source
        )
        let user = try await pipeline.loadData()

        #expect(user.id == 1)
    }

    // MARK: Filtered Pipeline Tests

    @Test("Filtered pipeline respects filter and limit parameters")
    func filteredPipeline() async throws {
        let source = DataSource<FilteredDataRequest> { request in
            #expect(request.limit == 10)
            #expect(request.filter == "active")
            return MockDataFixtures.userJSON
        }

        let pipeline = FilteredDataPipeline<User>(
            request: FilteredDataRequest(filter: "active", limit: 10),
            source: source
        )

        let user = try await pipeline.loadData()
        #expect(user.id == 1)
    }

    @Test("Custom pipelines support different request types")
    func customRequestTypes() async throws {
        let stringSource = DataSource<String> { identifier in
            identifier == "john" ? MockDataFixtures.userJSON : MockDataFixtures.usersJSON
        }

        let data = try await stringSource.fetch("john")
        let transformer = JSONTransformer<User>()
        let user = try transformer.transform(data)

        #expect(user.name == "John Doe")
    }

    // MARK: Transformer Composition Tests

    @Test("Composable transformers enable chaining")
    func composableTransformers() throws {
        let arrayTransformer = ArrayTransformer<User>()
        let users = try arrayTransformer.transform(MockDataFixtures.usersJSON)

        let filtered = users.filter { $0.id == 1 }

        #expect(filtered.count == 1)
        #expect(filtered[0].name == "John Doe")
    }
}

// MARK: - Custom Pipeline Error Handling

@Suite("Custom Pipeline Error Handling")
struct CustomPipelineErrorHandlingTests {

    @Test("Custom pipeline throws on invalid JSON")
    func customPipelineInvalidJSON() async throws {
        let source = DataSource<CustomDataRequest> { _ in MockDataFixtures.invalidJSON }
        let pipeline = CustomDataPipeline<User>(
            request: CustomDataRequest(identifier: "invalid", parameters: [:]),
            source: source
        )

        await #expect(throws: Error.self) {
            try await pipeline.loadData()
        }
    }

    @Test("Filtered pipeline propagates source errors")
    func filteredPipelineSourceErrors() async throws {
        enum FilterError: Error {
            case invalidFilter
        }

        let source = DataSource<FilteredDataRequest> { _ in
            throw FilterError.invalidFilter
        }

        let pipeline = FilteredDataPipeline<User>(
            request: FilteredDataRequest(filter: "invalid", limit: nil),
            source: source
        )

        await #expect(throws: FilterError.self) {
            try await pipeline.loadData()
        }
    }

    @Test("Custom source with empty data throws")
    func customSourceEmptyData() async throws {
        let emptySource = DataSource<CustomDataRequest> { _ in Data() }
        let pipeline = CustomDataPipeline<User>(
            request: CustomDataRequest(identifier: "empty", parameters: [:]),
            source: emptySource
        )

        await #expect(throws: Error.self) {
            try await pipeline.loadData()
        }
    }

    @Test("FileBasedSource handles invalid data gracefully")
    func fileBasedSourceInvalidData() async throws {
        let invalidSource = FileBasedSource.make(with: MockDataFixtures.invalidJSON)
        let pipeline = CustomDataPipeline<User>(
            request: CustomDataRequest(identifier: "corrupt", parameters: [:]),
            source: invalidSource
        )

        await #expect(throws: Error.self) {
            try await pipeline.loadData()
        }
    }
}

// MARK: - Custom Pipeline Integration Tests

@Suite("Custom Pipeline Integration")
struct CustomPipelineIntegrationTests {

    @Test("Custom pipeline with complex data flow")
    func customPipelineComplexFlow() async throws {
        let source = DataSource<CustomDataRequest> { request in
            request.identifier == "posts" ? MockDataFixtures.postJSON : MockDataFixtures.userJSON
        }

        let postPipeline = CustomDataPipeline<Post>(
            request: CustomDataRequest(identifier: "posts", parameters: [:]),
            source: source
        )

        let post = try await postPipeline.loadData()

        #expect(post.title == "Understanding Swift Concurrency")
        #expect(post.author.name == "John Doe")
    }

    @Test("Multiple custom pipeline types working together")
    func multiplePipelineTypes() async throws {
        let customSource = DataSource<CustomDataRequest> { _ in MockDataFixtures.userJSON }
        let filteredSource = DataSource<FilteredDataRequest> { _ in MockDataFixtures.userJSON }

        let customPipeline = CustomDataPipeline<User>(
            request: CustomDataRequest(identifier: "custom", parameters: [:]),
            source: customSource
        )

        let filteredPipeline = FilteredDataPipeline<User>(
            request: FilteredDataRequest(filter: "all", limit: nil),
            source: filteredSource
        )

        let user1 = try await customPipeline.loadData()
        let user2 = try await filteredPipeline.loadData()

        #expect(user1 == user2)
    }

    @Test("Custom pipeline with concurrent requests")
    func customPipelineConcurrentRequests() async throws {
        let source = DataSource<CustomDataRequest> { _ in MockDataFixtures.userJSON }
        let pipeline = CustomDataPipeline<User>(
            request: CustomDataRequest(identifier: "concurrent", parameters: [:]),
            source: source
        )

        async let result1 = pipeline.loadData()
        async let result2 = pipeline.loadData()
        async let result3 = pipeline.loadData()

        let (user1, user2, user3) = try await (result1, result2, result3)

        #expect(user1.id == user2.id)
        #expect(user2.id == user3.id)
    }

    @Test("Filtered pipeline with parameter variations")
    func filteredPipelineParameterVariations() async throws {
        let source = DataSource<FilteredDataRequest> { request in
            request.filter == "active" ? MockDataFixtures.userJSON : MockDataFixtures.usersJSON
        }

        let activePipeline = FilteredDataPipeline<User>(
            request: FilteredDataRequest(filter: "active", limit: 1),
            source: source
        )

        let user = try await activePipeline.loadData()
        #expect(user.name == "John Doe")
    }
}
