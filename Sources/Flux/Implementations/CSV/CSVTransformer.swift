import Foundation

public struct CSVTransformer<Model: Decodable>: DataTransformer {
    
    /// Configuration for how CSV headers should be handled
    public enum CSVHeaderConfiguration: Sendable {
        /// Use the first line of the CSV as headers
        case fromCSV
        /// Provide custom headers for CSV data (assumes no header row in CSV)
        case custom([String])
    }
    
    let headerConfiguation: CSVHeaderConfiguration
    
    public init(headerConfiguation: CSVHeaderConfiguration) {
        self.headerConfiguation = headerConfiguation
    }

    public func transform(_ data: Data) throws -> [Model] {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw CSVError.decodingFailed("Unable to decode CSV data as UTF-8")
        }

        let lines = csvString.split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        guard !lines.isEmpty else {
            return []
        }

        let headers: [String]
        let dataLines: [String]
        
        switch headerConfiguation {
        case .fromCSV:
            let headerLine = lines[0]
            headers = parseCSVLine(headerLine)
            dataLines = Array(lines.dropFirst())
            
        case let .custom(customHeaders):
            if customHeaders.isEmpty {
                // Generate generic column names when no custom headers provided
                let firstLine = parseCSVLine(lines[0])
                headers = (0..<firstLine.count).map { "column_\($0)" }
            } else {
                headers = customHeaders
            }
            dataLines = Array(lines)
        }

        var models: [Model] = []

        for (index, line) in dataLines.enumerated() {
            let values = parseCSVLine(line)

            guard values.count == headers.count else {
                let rowNumber = switch headerConfiguation {
                case .fromCSV: index + 2  // Account for header row
                case .custom: index + 1   // No header row to account for
                }
                throw CSVError.mismatchedColumns(
                    row: rowNumber,
                    expected: headers.count,
                    got: values.count
                )
            }

            var dictionary: [String: Any] = [:]
            for (header, value) in zip(headers, values) {
                dictionary[header] = value
            }

            let jsonData = try JSONSerialization.data(withJSONObject: dictionary)
            let model = try JSONDecoder().decode(Model.self, from: jsonData)
            models.append(model)
        }

        return models
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]

            if char == "\"" {
                insideQuotes.toggle()
                i = line.index(after: i)
            } else if char == "," && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
                i = line.index(after: i)
            } else {
                currentField.append(char)
                i = line.index(after: i)
            }
        }

        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        return fields
    }
}

/// Errors that can occur during CSV parsing and decoding.
public enum CSVError: Error, Sendable {
    /// Failed to decode CSV data as UTF-8
    case decodingFailed(String)

    /// CSV row has mismatched number of columns
    case mismatchedColumns(row: Int, expected: Int, got: Int)

    /// Unable to deserialize CSV values into model
    case modelDecodingFailed(String)
}
