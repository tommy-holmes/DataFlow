import Foundation

// MARK: - Test Models

/// Simple decodable model representing a user entity.
///
/// Used for testing basic JSON decoding, single-object pipelines,
/// and fundamental data transformation scenarios.
struct User: Decodable, Equatable, Sendable {
    let id: Int
    let name: String
    let email: String
}

// MARK: - Complex Models

/// Complex nested model representing a blog post with author metadata.
///
/// Used for testing:
/// - Advanced JSON decoding with nested structures
/// - Date decoding strategies (ISO8601)
/// - Relationship handling between entities
struct Post: Decodable, Equatable, Sendable {
    let id: Int
    let title: String
    let content: String
    let author: Author
    let createdAt: Date

    /// Nested author entity demonstrating relationship modeling.
    struct Author: Decodable, Equatable, Sendable {
        let id: Int
        let name: String
    }
}

// MARK: - Encodable Test Models

/// Simple encodable model for custom pipeline and request body testing.
///
/// Used for testing:
/// - JSON encoding in request bodies
/// - Custom data source parameters
/// - Bidirectional data flow scenarios
struct CustomDataModel: Encodable, Equatable, Sendable {
    let title: String
    let value: Int
}
