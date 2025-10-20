public struct RESTPipeline<D: Decodable>: ModelProvider {
    
    public var source: DataSource<RESTRequest>
    public var transformer: JSONTransformer<D>
    
    public init(
        request: RESTRequest,
        source: DataSource<RESTRequest>
    ) {
        self._request = request
        self.source = source
        self.transformer = .init()
    }
    
    private let _request: RESTRequest
    
    public func loadData() async throws -> D {
        let data = try await source.fetch(_request)
        return try transformer.transform(data)
    }
}
