import Testing
import Foundation
@testable import Flux

@Suite("Data Aggregation Pipeline")
struct DataAggregationTests {

    @Test("AggregationRequest stores identifier")
    func aggregationRequestStoresIdentifier() throws {
        let requests = [RESTRequest(path: "/users/1"), RESTRequest(path: "/users/2")]
        let aggregation = AggregationRequest(identifier: "users-batch", subRequests: requests)

        #expect(aggregation.identifier == "users-batch")
        #expect(aggregation.subRequests.count == 2)
    }

    @Test("AggregationRequest supports empty sub-requests")
    func aggregationRequestSupportsEmptySubRequests() throws {
        let aggregation = AggregationRequest<RESTRequest>(identifier: "empty", subRequests: [])

        #expect(aggregation.identifier == "empty")
        #expect(aggregation.subRequests.isEmpty)
    }

    @Test("AggregationRequest preserves sub-request order")
    func aggregationRequestPreservesSubRequestOrder() throws {
        let requests = [
            RESTRequest(path: "/api/1"),
            RESTRequest(path: "/api/2"),
            RESTRequest(path: "/api/3")
        ]
        let aggregation = AggregationRequest(identifier: "batch", subRequests: requests)

        for (index, request) in aggregation.subRequests.enumerated() {
            #expect(request.path == requests[index].path)
        }
    }

    @Test("AggregationTransformer passes through data")
    func aggregationTransformerPassesThroughData() throws {
        let testData = """
        [
            {"id": 1, "value": "first"},
            {"id": 2, "value": "second"}
        ]
        """.data(using: .utf8)!

        let transformer = AggregationTransformer()
        let result = try transformer.transform(testData)

        #expect(result == testData)
    }

    @Test("AggregationTransformer handles empty data")
    func aggregationTransformerHandlesEmptyData() throws {
        let emptyData = Data()

        let transformer = AggregationTransformer()
        let result = try transformer.transform(emptyData)

        #expect(result.isEmpty)
    }

    @Test("DataAggregationPipeline creates valid pipeline")
    func dataAggregationPipelineCreatesValidPipeline() throws {
        let requests = [RESTRequest(path: "/users/1"), RESTRequest(path: "/users/2")]
        let aggregation = AggregationRequest(identifier: "batch", subRequests: requests)
        let mockSource = DataSource<AggregationRequest<RESTRequest>> { _ in Data() }

        let pipeline = DataAggregationPipeline(
            request: aggregation,
            source: mockSource
        )

        #expect(type(of: pipeline.source) == DataSource<AggregationRequest<RESTRequest>>.self)
        #expect(type(of: pipeline.transformer) == AggregationTransformer.self)
    }

    @Test("DataAggregationPipeline loads aggregated data")
    func dataAggregationPipelineLoadsAggregatedData() async throws {
        let aggregatedJSON = """
        [
            {"id": 1, "name": "John Doe"},
            {"id": 2, "name": "Jane Smith"}
        ]
        """.data(using: .utf8)!

        let requests = [RESTRequest(path: "/users/1"), RESTRequest(path: "/users/2")]
        let aggregation = AggregationRequest(identifier: "users", subRequests: requests)

        let mockSource = DataSource<AggregationRequest<RESTRequest>> { _ in aggregatedJSON }

        let pipeline = DataAggregationPipeline(
            request: aggregation,
            source: mockSource
        )

        let result = try await pipeline.loadData()

        #expect(!result.isEmpty)
    }

    @Test("DataAggregationPipeline handles source errors")
    func dataAggregationPipelineHandlesSourceErrors() async throws {
        enum CustomError: Error {
            case aggregationFailed
        }

        let requests = [RESTRequest(path: "/users/1")]
        let aggregation = AggregationRequest(identifier: "batch", subRequests: requests)

        let failingSource = DataSource<AggregationRequest<RESTRequest>> { _ in
            throw CustomError.aggregationFailed
        }

        let pipeline = DataAggregationPipeline(
            request: aggregation,
            source: failingSource
        )

        await #expect(throws: CustomError.self) {
            try await pipeline.loadData()
        }
    }

    @Test("DataSource.aggregating creates sendable source")
    func dataSourceAggregatingCreatesSendableSource() throws {
        let source = DataSource<RESTRequest> { _ in Data() }
        let aggregatingSource = DataSource<AggregationRequest<RESTRequest>>
            .aggregating(pipelines: [source], parallelFetch: false)

        // Verify it's created with correct type
        #expect(type(of: aggregatingSource) == DataSource<AggregationRequest<RESTRequest>>.self)
    }

    @Test("Aggregation pipeline integrates with other pipelines")
    func aggregationPipelineIntegratesWithOtherPipelines() async throws {
        let requests = [
            RESTRequest(path: "/users/1"),
            RESTRequest(path: "/users/2"),
            RESTRequest(path: "/users/3")
        ]

        let aggregation = AggregationRequest(identifier: "users-batch", subRequests: requests)

        let mockSource = DataSource<AggregationRequest<RESTRequest>> { agg in
            let combined = """
            [
                {"id": 1, "name": "John", "email": "john@example.com"},
                {"id": 2, "name": "Jane", "email": "jane@example.com"},
                {"id": 3, "name": "Bob", "email": "bob@example.com"}
            ]
            """.data(using: .utf8)!
            return combined
        }

        let pipeline = DataAggregationPipeline(
            request: aggregation,
            source: mockSource
        )

        let result = try await pipeline.loadData()

        #expect(!result.isEmpty)
    }
}

