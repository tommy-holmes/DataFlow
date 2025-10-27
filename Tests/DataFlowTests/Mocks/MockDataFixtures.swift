import Foundation

// MARK: - Mock Data Fixtures

/// Centralized repository of JSON mock data for testing data pipelines.
///
/// This enum provides pre-formatted JSON data as `Data` instances,
/// eliminating the need for external fixture files and making tests
/// self-contained and discoverable.
///
/// Organized by data type:
/// - Single objects: `userJSON`, `postJSON`
/// - Collections: `usersJSON`
/// - Error cases: `invalidJSON`, `incompleteJSON`
/// - Dynamic generation: `customDataJSON(_:)`
enum MockDataFixtures {

    // MARK: - Valid Single Object JSON

    /// Single user JSON for basic decoding tests.
    ///
    /// Contains all required fields for `User` model.
    /// Used in: REST pipeline tests, basic decoding tests, integration tests.
    static let userJSON = """
    {
        "id": 1,
        "name": "John Doe",
        "email": "john@example.com"
    }
    """.data(using: .utf8)!

    /// Complex post JSON with nested author and ISO8601 date.
    ///
    /// Contains all required fields for `Post` model including nested `Author`.
    /// Used in: Advanced decoding tests, date strategy tests, nested model tests.
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

    // MARK: - Collection JSON

    /// Array of user JSON for testing collection transformers.
    ///
    /// Contains two distinct users with unique IDs.
    /// Used in: `ArrayTransformer` tests, batch processing tests.
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

    // MARK: - Error Case JSON

    /// Malformed JSON for testing error handling.
    ///
    /// Invalid JSON structure that should fail decoding.
    /// Used in: Error handling tests, validation tests.
    static let invalidJSON = "{ invalid json }".data(using: .utf8)!

    /// Incomplete JSON missing required fields.
    ///
    /// Valid JSON structure but missing `email` field required by `User` model.
    /// Used in: Missing field tests, validation error tests.
    static let incompleteJSON = """
    {
        "id": 1,
        "name": "John"
    }
    """.data(using: .utf8)!

    // MARK: - Dynamic JSON Generation

    /// Generates JSON data from a `CustomDataModel` instance.
    ///
    /// Encodes the provided model using `JSONEncoder` for testing
    /// request body construction and custom data workflows.
    ///
    /// - Parameter value: The model to encode
    /// - Returns: JSON-encoded `Data`
    ///
    /// Used in: Request body tests, custom pipeline tests.
    static func customDataJSON(_ value: CustomDataModel) -> Data {
        try! JSONEncoder().encode(value)
    }
}
