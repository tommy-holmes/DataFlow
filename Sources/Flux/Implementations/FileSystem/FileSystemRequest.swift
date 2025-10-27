import Foundation

public struct FileSystemRequest: Sendable {
    public enum Format: Sendable {
        case json
        case propertyList
        case raw
    }

    public let path: String
    public let bundle: Bundle
    public let format: Format

    public init(
        path: String,
        bundle: Bundle = .main,
        format: Format = .json
    ) {
        self.path = path
        self.bundle = bundle
        self.format = format
    }
}
