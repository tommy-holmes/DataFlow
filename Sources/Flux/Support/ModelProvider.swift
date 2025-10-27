/// Protocol defining the contract for a complete data pipeline.
///
/// A `ModelProvider` orchestrates a `DataSource` and `DataTransformer` to fetch and decode data
/// into a strongly-typed model. This protocol enables composable, reusable pipelines with
/// support for caching, retries, and other middleware.
///
/// ## Conformance
/// All pipelines must expose their request for caching and observability:
///
/// ```swift
/// struct MyPipeline<D: Decodable>: ModelProvider {
///     public let request: MyRequest
///     public var source: DataSource<MyRequest> { mySource }
///     public var transformer: JSONTransformer<D> { JSONTransformer() }
///
///     public func loadData() async throws -> D {
///         let data = try await source.fetch(request)
///         return try transformer.transform(data)
///     }
/// }
/// ```
///
/// ## Thread Safety
/// All types conforming to `ModelProvider` must be `Sendable` and safe to use across
/// concurrent task boundaries.
public protocol ModelProvider: Sendable {
    /// The model type this pipeline decodes into.
    associatedtype Model

    /// The transformer that converts raw data into the model.
    associatedtype Transformer: DataTransformer

    /// The request type this pipeline accepts.
    associatedtype Request: Sendable

    /// The request to be executed.
    ///
    /// This property must be exposed for middleware like caching and retries to work correctly.
    /// It enables observability and enables generalized caching strategies.
    var request: Request { get }

    /// The data source that fetches raw data.
    var source: DataSource<Request> { get }

    /// The transformer that decodes raw data.
    var transformer: Transformer { get }

    /// Loads and decodes data into a strongly-typed model.
    ///
    /// This method orchestrates the full pipeline: fetch from source, transform to model.
    /// Respects task cancellation and propagates errors from either source or transformer.
    ///
    /// - Returns: The decoded model
    /// - Throws: Errors from the data source or transformer
    func loadData() async throws -> Model
}
