public protocol ModelProvider: Sendable {
    associatedtype Model
    associatedtype Transformer: DataTransformer
    associatedtype Request: Requestable
    
    var source: DataSource<Request> { get }
    var transformer: Transformer { get }
    
    func loadData() async throws -> Model
}
