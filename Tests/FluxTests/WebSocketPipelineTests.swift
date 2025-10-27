import Testing
import Foundation
@testable import Flux

@Suite("WebSocket Pipeline")
struct WebSocketPipelineTests {

    @Test("WebSocketRequest requires URL")
    func webSocketRequestRequiresURL() throws {
        let url = URL(string: "ws://example.com/stream")!
        let request = WebSocketRequest(url: url)

        #expect(request.url == url)
        #expect(request.headers.isEmpty)
        #expect(request.messageCount == nil)
    }

    @Test("WebSocketRequest supports custom headers")
    func webSocketRequestSupportsCustomHeaders() throws {
        let url = URL(string: "ws://example.com/stream")!
        let headers = ["Authorization": "Bearer token123", "Custom": "header-value"]
        let request = WebSocketRequest(url: url, headers: headers)

        #expect(request.headers == headers)
        #expect(request.headers.count == 2)
    }

    @Test("WebSocketRequest supports message count limit")
    func webSocketRequestSupportsMessageCountLimit() throws {
        let url = URL(string: "ws://example.com/stream")!
        let request = WebSocketRequest(url: url, messageCount: 5)

        #expect(request.messageCount == 5)
    }

    @Test("WebSocketTransformer decodes JSON message")
    func webSocketTransformerDecodesJSON() throws {
        let jsonData = """
        {
            "id": 1,
            "name": "John Doe",
            "email": "john@example.com"
        }
        """.data(using: .utf8)!

        let transformer = WebSocketTransformer<User>()
        let user = try transformer.transform(jsonData)

        #expect(user.id == 1)
        #expect(user.name == "John Doe")
    }

    @Test("WebSocketTransformer throws on invalid JSON")
    func webSocketTransformerThrowsOnInvalidJSON() throws {
        let invalidJSON = "not json".data(using: .utf8)!

        let transformer = WebSocketTransformer<User>()

        #expect(throws: Error.self) {
            try transformer.transform(invalidJSON)
        }
    }

    @Test("WebSocketPipeline creates valid pipeline")
    func webSocketPipelineCreatesValidPipeline() throws {
        let url = URL(string: "ws://example.com/stream")!
        let request = WebSocketRequest(url: url)
        let mockSource = DataSource<WebSocketRequest> { _ in Data() }

        let pipeline = WebSocketPipeline<User>(
            request: request,
            source: mockSource
        )

        #expect(type(of: pipeline.source) == DataSource<WebSocketRequest>.self)
        #expect(type(of: pipeline.transformer) == WebSocketTransformer<User>.self)
    }

    @Test("WebSocketPipeline loads data from source")
    func webSocketPipelineLoadsDataFromSource() async throws {
        let jsonData = """
        {
            "id": 1,
            "name": "John Doe",
            "email": "john@example.com"
        }
        """.data(using: .utf8)!

        let mockSource = DataSource<WebSocketRequest> { _ in jsonData }
        let url = URL(string: "ws://example.com/stream")!
        let request = WebSocketRequest(url: url)

        let pipeline = WebSocketPipeline<User>(
            request: request,
            source: mockSource
        )

        let user = try await pipeline.loadData()

        #expect(user.id == 1)
        #expect(user.name == "John Doe")
    }

    @Test("WebSocketPipeline handles source errors")
    func webSocketPipelineHandlesSourceErrors() async throws {
        enum CustomError: Error {
            case connectionLost
        }

        let failingSource = DataSource<WebSocketRequest> { _ in
            throw CustomError.connectionLost
        }

        let url = URL(string: "ws://example.com/stream")!
        let request = WebSocketRequest(url: url)

        let pipeline = WebSocketPipeline<User>(
            request: request,
            source: failingSource
        )

        await #expect(throws: CustomError.self) {
            try await pipeline.loadData()
        }
    }

    @Test("WebSocketPipeline handles invalid JSON from stream")
    func webSocketPipelineHandlesInvalidJSONFromStream() async throws {
        let invalidJSON = "not valid json".data(using: .utf8)!

        let mockSource = DataSource<WebSocketRequest> { _ in invalidJSON }

        let url = URL(string: "ws://example.com/stream")!
        let request = WebSocketRequest(url: url)

        let pipeline = WebSocketPipeline<User>(
            request: request,
            source: mockSource
        )

        await #expect(throws: Error.self) {
            try await pipeline.loadData()
        }
    }
}
