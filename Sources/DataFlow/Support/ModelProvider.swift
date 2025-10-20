public protocol ModelProvider: Sendable {
    associatedtype Model
    associatedtype Transformer: DataTransformer
    
    var source: DataSource { get }
    var transformer: Transformer { get }
    
    func loadData() async throws -> Model
}
