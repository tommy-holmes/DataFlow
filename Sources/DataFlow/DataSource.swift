import Foundation

public struct DataSource: Sendable {
    public var fetch: @Sendable (Request) async throws -> Data
}
