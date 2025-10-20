import Foundation

public struct DataSource<R: Requestable>: Sendable {
    public typealias FetchFunction = @Sendable (R) async throws -> Data
    
    public var fetch: FetchFunction
    
    public init(fetch: @escaping FetchFunction) {
        self.fetch = fetch
    }
}
