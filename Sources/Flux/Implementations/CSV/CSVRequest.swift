import Foundation

public struct CSVRequest: Sendable {
    public let path: String

    public init(path: String) {
        self.path = path
    }
}
