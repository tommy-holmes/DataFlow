import Foundation

public struct CSVRequest: Sendable {
    public let path: String
    public let bundle: Bundle
    public let hasHeader: Bool

    public init(
        path: String,
        bundle: Bundle = .main,
        hasHeader: Bool = true
    ) {
        self.path = path
        self.bundle = bundle
        self.hasHeader = hasHeader
    }
}
