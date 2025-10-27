import Foundation
@testable import DataFlow

// MARK: - Custom Request Types

/// Request type for custom data sources with identifier-based routing.
///
/// Flexible request structure that supports arbitrary key-value parameters
/// alongside a primary identifier. Designed for testing non-REST data sources
/// like caches, files, or custom protocols.
///
/// ## Properties
/// - `identifier`: Primary routing key (e.g., "user-1", "cache-key")
/// - `parameters`: Additional key-value metadata for filtering/sorting
///
/// ## Usage
/// ```swift
/// let request = CustomDataRequest(
///     identifier: "user-1",
///     parameters: ["include": "profile", "expand": "posts"]
/// )
/// ```
///
/// ## Test Coverage
/// - Identifier-based routing
/// - Parameter passing to sources
/// - Custom pipeline integration
/// - File-based source compatibility
struct CustomDataRequest: Sendable {
    let identifier: String
    let parameters: [String: String]
}

// MARK: - Filtered Request Types

/// Request type for pipelines requiring filtering and pagination.
///
/// Specialized request structure for scenarios requiring query refinement.
/// Demonstrates how request types can encode domain-specific requirements.
///
/// ## Properties
/// - `filter`: String-based filter criteria (e.g., "active", "published")
/// - `limit`: Optional result count constraint for pagination
///
/// ## Usage
/// ```swift
/// let request = FilteredDataRequest(
///     filter: "active",
///     limit: 10
/// )
/// ```
///
/// ## Test Coverage
/// - Filter parameter application
/// - Optional limit handling
/// - Filtered pipeline integration
/// - Parameter variation scenarios
struct FilteredDataRequest: Sendable {
    let filter: String
    let limit: Int?
}

// MARK: - Mock Data Sources

/// File-based data source factory for testing custom pipelines.
///
/// Creates `DataSource<CustomDataRequest>` instances that return
/// pre-configured `Data` regardless of request parameters.
/// Useful for testing pipelines with static mock data.
///
/// ## Implementation
/// Ignores request parameters and returns the provided data directly,
/// simulating a file or cache lookup that always succeeds.
///
/// ## Usage
/// ```swift
/// let source = FileBasedSource.make(with: mockUserJSON)
/// let pipeline = CustomDataPipeline<User>(
///     request: CustomDataRequest(identifier: "file", parameters: [:]),
///     source: source
/// )
/// let user = try await pipeline.loadData()
/// ```
///
/// ## Test Coverage
/// - Static data provisioning
/// - Custom request handling
/// - Integration with CustomDataPipeline
/// - Error propagation for invalid data
enum FileBasedSource {

    /// Creates a data source that returns the specified data.
    ///
    /// - Parameter data: The `Data` to return for any request
    /// - Returns: A `DataSource<CustomDataRequest>` instance
    static func make(with data: Data) -> DataSource<CustomDataRequest> {
        DataSource { _ in data }
    }
}
