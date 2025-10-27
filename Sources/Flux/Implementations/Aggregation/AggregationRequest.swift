import Foundation

public struct AggregationRequest<T: Sendable>: Sendable {
    public let identifier: String
    public let subRequests: [T]

    public init(identifier: String, subRequests: [T]) {
        self.identifier = identifier
        self.subRequests = subRequests
    }
}
