import Foundation

public struct FileSystemTransformer<Model: Decodable>: DataTransformer {
    public let format: FileSystemRequest.Format

    public init(format: FileSystemRequest.Format = .json) {
        self.format = format
    }

    public func transform(_ data: Data) throws -> Model {
        switch format {
        case .json:
            return try JSONDecoder().decode(Model.self, from: data)
        case .propertyList:
            return try PropertyListDecoder().decode(Model.self, from: data)
        case .raw:
            throw FileSystemError.rawFormatRequiresManualDecoding
        }
    }
}

/// Errors that can occur when loading files from the file system.
public enum FileSystemError: Error, Sendable {
    /// File not found at specified path
    case fileNotFound(String)

    /// Failed to read file data
    case readFailed(path: String, description: String)

    /// Failed to decode file data into model
    case decodingFailed(description: String)

    /// Raw format requires manual decoding - use FileSystemTransformer<Data> instead
    case rawFormatRequiresManualDecoding
}
