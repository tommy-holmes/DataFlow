import Foundation

public struct CSVPipeline<D: Decodable>: ModelProvider {
    public let request: CSVRequest
    public let source: DataSource<CSVRequest>
    public let transformer: CSVTransformer<D>

    public init(
        request: CSVRequest,
        source: DataSource<CSVRequest>,
        headerConfiguation: CSVTransformer<D>.CSVHeaderConfiguration = .fromCSV
    ) {
        self.request = request
        self.source = source
        self.transformer = CSVTransformer<D>(headerConfiguation: headerConfiguation)
    }

    public func loadData() async throws -> [D] {
        let data = try await source.fetch(request)
        return try transformer.transform(data)
    }
}

public extension DataSource
where Type == CSVRequest {
    /// Creates a data source that loads CSV files from the app bundle.
    ///
    /// - Returns: A DataSource that fetches CSV data from bundle resources
    static func from(bundle: Bundle = .main) -> Self {
        DataSource { request in
            guard let url = bundle.url(
                forResource: request.path,
                withExtension: "csv"
            ) else {
                throw CSVSourceError.fileNotFound(request.path)
            }

            do {
                let data = try Data(contentsOf: url)
                return data
            } catch {
                throw CSVSourceError.readFailed(
                    path: request.path,
                    description: error.localizedDescription
                )
            }
        }
    }
    /// Creates a data source from raw CSV data.
    ///
    /// - Parameter csvData: The raw CSV data to use as the source
    /// - Returns: A DataSource that provides the given CSV data
    static func from(csvData: Data) -> Self {
        DataSource { _ in csvData }
    }
}

/// Errors that can occur when loading CSV files.
public enum CSVSourceError: Error, Sendable {
    /// CSV file not found in bundle
    case fileNotFound(String)

    /// Failed to read CSV file
    case readFailed(path: String, description: String)
}
