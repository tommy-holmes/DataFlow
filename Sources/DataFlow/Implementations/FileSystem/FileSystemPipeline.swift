import Foundation

public struct FileSystemPipeline<D: Decodable>: ModelProvider {
    public let request: FileSystemRequest
    public var source: DataSource<FileSystemRequest>
    public var transformer: FileSystemTransformer<D>

    public init(request: FileSystemRequest, source: DataSource<FileSystemRequest>) {
        self.request = request
        self.source = source
        self.transformer = FileSystemTransformer<D>(format: request.format)
    }

    public func loadData() async throws -> D {
        let data = try await source.fetch(request)
        return try transformer.transform(data)
    }
}

public extension DataSource where Type == FileSystemRequest {
    /// Creates a data source that loads files from the app bundle.
    ///
    /// - Returns: A DataSource that fetches file data from bundle resources
    static func fromBundle() -> Self {
        DataSource { request in
            let fileExtension: String? = {
                switch request.format {
                case .json:
                    return "json"
                case .propertyList:
                    return "plist"
                case .raw:
                    return nil
                }
            }()

            guard let url = request.bundle.url(
                forResource: request.path,
                withExtension: fileExtension
            ) else {
                throw FileSystemError.fileNotFound(request.path)
            }

            do {
                let data = try Data(contentsOf: url)
                return data
            } catch {
                throw FileSystemError.readFailed(
                    path: url.path,
                    description: error.localizedDescription
                )
            }
        }
    }

    /// Creates a data source that loads files from a specified directory.
    ///
    /// - Parameter basePath: The base directory path to search within
    /// - Returns: A DataSource that fetches file data from the file system
    static func fromFileManager(at basePath: String) -> Self {
        DataSource { request in
            let baseURL = URL(fileURLWithPath: basePath)
            let fileURL = baseURL.appendingPathComponent(request.path)

            do {
                let data = try Data(contentsOf: fileURL)
                return data
            } catch {
                throw FileSystemError.readFailed(
                    path: fileURL.path,
                    description: error.localizedDescription
                )
            }
        }
    }
}
