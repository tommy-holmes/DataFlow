import Testing
import Foundation
@testable import Flux

@Suite("CSV Pipeline")
struct CSVPipelineTests {

    // MARK: - Basic Loading Tests

    @Test("CSVPipeline successfully loads and parses CSV from bundle")
    func loadCSVFromBundle() async throws {
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

    @Test("CSVPipeline handles empty CSV")
    func csvHandlesEmptyData() async throws {
        struct SimpleUser: Decodable {
            let name: String
            let email: String
        }

        let mockSource = DataSource<CSVRequest> { _ in
            """
            name,email
            """.data(using: .utf8)!
        }

        let pipeline = CSVPipeline<SimpleUser>(
            request: CSVRequest(path: "empty.csv"),
            source: mockSource
        )

        let users = try await pipeline.loadData()
        #expect(users.isEmpty)
    }

    // MARK: - Header Configuration Tests

    @Test("CSVPipeline with fromCSV header configuration")
    func csvPipelineFromCSVHeaders() async throws {
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
            request: CSVRequest(path: "users"),
            source: mockSource,
            headerConfiguation: .fromCSV
        )

        let users = try await pipeline.loadData()
        #expect(users.count == 1)
        #expect(users[0].name == "John Doe")
    }

    @Test("CSVPipeline with custom header configuration")
    func csvPipelineCustomHeaders() async throws {
        struct SimpleUser: Decodable {
            let name: String
            let email: String
        }

        let mockSource = DataSource<CSVRequest> { _ in
            """
            John Doe,john@example.com
            Jane Smith,jane@example.com
            """.data(using: .utf8)!
        }

        let pipeline = CSVPipeline<SimpleUser>(
            request: CSVRequest(path: "users"),
            source: mockSource,
            headerConfiguation: .custom(["name", "email"])
        )

        let users = try await pipeline.loadData()
        #expect(users.count == 2)
        #expect(users[0].name == "John Doe")
        #expect(users[1].email == "jane@example.com")
    }

    @Test("CSVPipeline with custom empty headers generates generic column names")
    func csvPipelineEmptyCustomHeaders() async throws {
        struct SimpleUser: Decodable {
            let column_0: String
            let column_1: String
        }

        let mockSource = DataSource<CSVRequest> { _ in
            """
            John Doe,john@example.com
            """.data(using: .utf8)!
        }

        let pipeline = CSVPipeline<SimpleUser>(
            request: CSVRequest(path: "users"),
            source: mockSource,
            headerConfiguation: .custom([])
        )

        let users = try await pipeline.loadData()
        #expect(users.count == 1)
        #expect(users[0].column_0 == "John Doe")
        #expect(users[0].column_1 == "john@example.com")
    }

    // MARK: - DataSource Factory Tests

    @Test("DataSource.from(csvData:) creates data source from raw CSV")
    func dataSourceFromCSVData() async throws {
        struct SimpleUser: Decodable {
            let name: String
            let email: String
        }

        let csvData = """
        name,email
        John Doe,john@example.com
        """.data(using: .utf8)!

        let source = DataSource<CSVRequest>.from(csvData: csvData)
        let pipeline = CSVPipeline<SimpleUser>(
            request: CSVRequest(path: "users"),
            source: source
        )

        let users = try await pipeline.loadData()
        #expect(users.count == 1)
        #expect(users[0].name == "John Doe")
    }

    // MARK: - CSV Parsing Tests

    @Test("CSVPipeline handles quoted fields with commas")
    func csvHandlesQuotedFields() async throws {
        struct SimpleUser: Decodable {
            let name: String
            let bio: String
        }

        let mockSource = DataSource<CSVRequest> { _ in
            """
            name,bio
            John Doe,"Software Engineer, loves coding"
            """.data(using: .utf8)!
        }

        let pipeline = CSVPipeline<SimpleUser>(
            request: CSVRequest(path: "users"),
            source: mockSource
        )

        let users = try await pipeline.loadData()
        #expect(users.count == 1)
        #expect(users[0].bio == "Software Engineer, loves coding")
    }

    @Test("CSVPipeline handles whitespace trimming")
    func csvHandlesWhitespaceTrimming() async throws {
        struct SimpleUser: Decodable {
            let name: String
            let email: String
        }

        let mockSource = DataSource<CSVRequest> { _ in
            """
            name,email
              John Doe  ,  john@example.com
            """.data(using: .utf8)!
        }

        let pipeline = CSVPipeline<SimpleUser>(
            request: CSVRequest(path: "users"),
            source: mockSource
        )

        let users = try await pipeline.loadData()
        #expect(users.count == 1)
        #expect(users[0].name == "John Doe")
        #expect(users[0].email == "john@example.com")
    }

    // MARK: - Error Handling Tests

    @Test("CSVPipeline throws on mismatched columns with fromCSV headers")
    func csvThrowsOnMismatchedColumnsFromCSV() async throws {
        struct SimpleUser: Decodable {
            let name: String
            let email: String
        }

        let mockSource = DataSource<CSVRequest> { _ in
            """
            name,email
            John Doe
            """.data(using: .utf8)!
        }

        let pipeline = CSVPipeline<SimpleUser>(
            request: CSVRequest(path: "users"),
            source: mockSource,
            headerConfiguation: .fromCSV
        )

        await #expect(throws: CSVError.self) {
            _ = try await pipeline.loadData()
        }
    }

    @Test("CSVPipeline throws on mismatched columns with custom headers")
    func csvThrowsOnMismatchedColumnsCustom() async throws {
        struct SimpleUser: Decodable {
            let name: String
            let email: String
        }

        let mockSource = DataSource<CSVRequest> { _ in
            """
            John Doe
            """.data(using: .utf8)!
        }

        let pipeline = CSVPipeline<SimpleUser>(
            request: CSVRequest(path: "users"),
            source: mockSource,
            headerConfiguation: .custom(["name", "email"])
        )

        await #expect(throws: CSVError.self) {
            _ = try await pipeline.loadData()
        }
    }

    @Test("CSVPipeline throws on invalid UTF-8 data")
    func csvThrowsOnInvalidUTF8() async throws {
        struct SimpleUser: Decodable {
            let name: String
            let email: String
        }

        let mockSource = DataSource<CSVRequest> { _ in
            Data([0xFF, 0xFE]) // Invalid UTF-8
        }

        let pipeline = CSVPipeline<SimpleUser>(
            request: CSVRequest(path: "users"),
            source: mockSource
        )

        await #expect(throws: CSVError.self) {
            _ = try await pipeline.loadData()
        }
    }

    @Test("CSVPipeline throws CSVSourceError for missing file")
    func csvSourceThrowsFileNotFound() async throws {
        let source = DataSource<CSVRequest>.from(bundle: .main)

        await #expect(throws: CSVSourceError.self) {
            _ = try await source.fetch(CSVRequest(path: "nonexistent"))
        }
    }

    // MARK: - Request Tests

    @Test("CSVRequest initializes with path")
    func csvRequestInitialization() {
        let request = CSVRequest(path: "data.csv")
        #expect(request.path == "data.csv")
    }

    @Test("CSVRequest is Sendable")
    func csvRequestIsSendable() {
        let request = CSVRequest(path: "data.csv")
        // CSVRequest is Sendable (verifiable at compile time via struct conformance)
        let _: CSVRequest = request
    }
}
