import Testing
import Foundation
@testable import DataFlow

@Suite("CSV Pipeline")
struct CSVPipelineTests {

    @Test("CSVPipeline successfully loads and parses CSV from bundle")
    func loadCSVFromBundle() async throws {
        // Create a simple decodable model that works with CSV string values
        struct SimpleUser: Decodable {
            let name: String
            let email: String
        }

        let mockSource = DataSource<CSVRequest> { request in
            """
            name,email
            John Doe,john@example.com
            Jane Smith,jane@example.com
            """.data(using: .utf8)!
        }

        let pipeline = CSVPipeline<SimpleUser>(
            request: CSVRequest(path: "users"),
            source: mockSource
        )

        let users = try await pipeline.loadData()

        #expect(users.count == 2)
        #expect(users[0].name == "John Doe")
        #expect(users[1].email == "jane@example.com")
    }

    @Test("CSVRequest defaults to main bundle")
    func csvRequestDefaultBundle() {
        let request = CSVRequest(path: "data.csv")
        #expect(request.bundle == .main)
    }

    @Test("CSVRequest respects hasHeader parameter")
    func csvRequestHeaderParameter() {
        let request = CSVRequest(path: "data.csv", hasHeader: false)
        #expect(request.hasHeader == false)

        let requestWithHeader = CSVRequest(path: "data.csv", hasHeader: true)
        #expect(requestWithHeader.hasHeader == true)
    }

    @Test("CSVPipeline handles single row CSV")
    func csvHandlesSingleRow() async throws {
        struct SimpleUser: Decodable {
            let name: String
            let email: String
        }

        let mockSource = DataSource<CSVRequest> { _ in
            """
            name,email
            John Doe,john@example.com
            """.data(using: .utf8)!
        }

        let pipeline = CSVPipeline<SimpleUser>(
            request: CSVRequest(path: "single.csv"),
            source: mockSource
        )

        let users = try await pipeline.loadData()

        #expect(users.count == 1)
        #expect(users[0].name == "John Doe")
    }
}
