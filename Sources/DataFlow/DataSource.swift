import Foundation

public struct DataSource<Type>: Sendable {
    public typealias FetchFunction = @Sendable (Type) async throws -> Data
    
    public var fetch: FetchFunction
    
    public init(fetch: @escaping FetchFunction) {
        self.fetch = fetch
    }
}
