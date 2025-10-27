import Foundation

public struct CSVTransformer<Model: Decodable>: DataTransformer {
    public init() { }

    public func transform(_ data: Data) throws -> [Model] {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw CSVError.decodingFailed("Unable to decode CSV data as UTF-8")
        }

        let lines = csvString.split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        guard !lines.isEmpty else {
            return []
        }

        let headerLine = lines[0]
        let headers = parseCSVLine(headerLine)

        let dataLines = Array(lines.dropFirst())

        var models: [Model] = []

        for (index, line) in dataLines.enumerated() {
            let values = parseCSVLine(line)

            guard values.count == headers.count else {
                throw CSVError.mismatchedColumns(
                    row: index + 2,
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
