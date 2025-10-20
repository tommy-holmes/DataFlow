public protocol DataTransformer: Sendable {
    associatedtype Input
    associatedtype Output
    
    func transform(_ data: Input) throws -> Output
}
