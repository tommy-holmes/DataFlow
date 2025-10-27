import Testing
import Foundation
@testable import Flux

@Suite("FileSystem Pipeline")
struct FileSystemPipelineTests {

    @Test("FileSystemRequest defaults to JSON format")
    func requestDefaultsToJSON() {
        let request = FileSystemRequest(path: "data.json")
        #expect(request.format == .json)
    }

    @Test("FileSystemRequest supports all formats")
    func requestSupportsAllFormats() {
        let jsonRequest = FileSystemRequest(path: "data.json", format: .json)
        let plistRequest = FileSystemRequest(path: "data.plist", format: .propertyList)
        let rawRequest = FileSystemRequest(path: "data.bin", format: .raw)

        #expect(jsonRequest.format == .json)
        #expect(plistRequest.format == .propertyList)
        #expect(rawRequest.format == .raw)
    }

    @Test("FileSystemRequest defaults to main bundle")
    func requestDefaultsToMainBundle() {
        let request = FileSystemRequest(path: "data.json")
        #expect(request.bundle == .main)
    }

    @Test("FileSystemTransformer decodes JSON format")
    func transformerDecodesJSON() throws {
        let jsonData = """
        {
            "id": 1,
            "name": "John Doe",
            "email": "john@example.com"
        }
        """.data(using: .utf8)!

        let transformer = FileSystemTransformer<User>(format: .json)
        let user = try transformer.transform(jsonData)

        #expect(user.id == 1)
        #expect(user.name == "John Doe")
    }

    @Test("FileSystemPipeline loads JSON from bundle source")
    func loadJSONFromBundle() async throws {
        let jsonData = """
        {
            "id": 1,
            "name": "John Doe",
            "email": "john@example.com"
        }
        """.data(using: .utf8)!

        let mockSource = DataSource<FileSystemRequest> { _ in jsonData }

        let pipeline = FileSystemPipeline<User>(
            request: FileSystemRequest(path: "user.json"),
            source: mockSource
        )

        let user = try await pipeline.loadData()

        #expect(user.id == 1)
        #expect(user.name == "John Doe")
    }

    @Test("FileSystemPipeline handles file not found errors")
    func handleFileNotFoundErrors() async throws {
        let mockSource = DataSource<FileSystemRequest> { _ in
            throw FileSystemError.fileNotFound("missing.json")
        }

        let pipeline = FileSystemPipeline<User>(
            request: FileSystemRequest(path: "missing.json"),
            source: mockSource
        )

        await #expect(throws: FileSystemError.self) {
            try await pipeline.loadData()
        }
    }

    @Test("FileSystemPipeline handles invalid JSON decoding")
    func handleInvalidJSONDecoding() async throws {
        let invalidJSON = "{ invalid }".data(using: .utf8)!

        let mockSource = DataSource<FileSystemRequest> { _ in invalidJSON }

        let pipeline = FileSystemPipeline<User>(
            request: FileSystemRequest(path: "invalid.json"),
            source: mockSource
        )

        await #expect(throws: Error.self) {
            try await pipeline.loadData()
        }
    }
}
