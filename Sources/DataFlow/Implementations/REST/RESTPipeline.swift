public struct RESTPipeline<D: Decodable>: ModelProvider {

    public let request: RESTRequest
    public var source: DataSource<RESTRequest>
    public var transformer: JSONTransformer<D>

    public init(
        request: RESTRequest,
        source: DataSource<RESTRequest>
    ) {
        self.request = request
        self.source = source
        self.transformer = .init()
    }

    public func loadData() async throws -> D {
        let data = try await source.fetch(request)
        return try transformer.transform(data)
    }
}
