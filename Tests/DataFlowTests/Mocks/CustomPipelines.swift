import Foundation
@testable import DataFlow

// MARK: - Custom Pipeline Implementations

/// Custom pipeline for non-REST data sources with flexible request parameters.
///
/// Demonstrates the flexibility of the `ModelProvider` protocol by implementing
/// a pipeline that uses `CustomDataRequest` instead of `RESTRequest`.
///
/// ## Architecture
/// - Request: `CustomDataRequest` with identifier and key-value parameters
/// - Source: Any `DataSource<CustomDataRequest>`
/// - Transformer: `JSONTransformer<D>` for type-safe decoding
///
/// ## Usage
/// ```swift
/// let pipeline = CustomDataPipeline<User>(
///     request: CustomDataRequest(identifier: "user-1", parameters: [:]),
///     source: customSource
/// )
/// let user = try await pipeline.loadData()
/// ```
///
/// ## Test Coverage
/// - Non-REST request routing
/// - Parameter passing to data sources
/// - Custom identifier-based data fetching
/// - Integration with file-based sources
struct CustomDataPipeline<D: Decodable>: ModelProvider {
    var source: DataSource<CustomDataRequest>
    var transformer: JSONTransformer<D>

    private let request: CustomDataRequest

    init(request: CustomDataRequest, source: DataSource<CustomDataRequest>) {
        self.request = request
        self.source = source
        self.transformer = JSONTransformer<D>()
    }

    func loadData() async throws -> D {
        let data = try await source.fetch(request)
        return try transformer.transform(data)
    }
}

// MARK: - Filtered Pipeline

/// Pipeline with built-in filtering and limiting capabilities.
///
/// Extends the basic pipeline pattern with query parameters for
/// filtering and pagination. Demonstrates how domain-specific
/// requirements can be encoded into custom request types.
///
/// ## Request Parameters
/// - `filter`: String-based filter criteria (e.g., "active", "archived")
/// - `limit`: Optional maximum number of results
///
/// ## Usage
/// ```swift
/// let pipeline = FilteredDataPipeline<User>(
///     request: FilteredDataRequest(filter: "active", limit: 10),
///     source: filteredSource
/// )
/// let user = try await pipeline.loadData()
/// ```
///
/// ## Test Coverage
/// - Filter parameter validation
/// - Limit parameter application
/// - Conditional query construction
/// - Parameter variation scenarios
struct FilteredDataPipeline<D: Decodable>: ModelProvider {
    var source: DataSource<FilteredDataRequest>
    var transformer: JSONTransformer<D>

    private let request: FilteredDataRequest

    init(request: FilteredDataRequest, source: DataSource<FilteredDataRequest>) {
        self.request = request
        self.source = source
        self.transformer = JSONTransformer<D>()
    }

    func loadData() async throws -> D {
        let data = try await source.fetch(request)
        return try transformer.transform(data)
    }
}
