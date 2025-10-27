import Foundation
@testable import DataFlow

// MARK: - Collection Transformers

/// Transforms JSON array data into strongly-typed model collections.
///
/// Generic transformer that decodes JSON arrays into Swift arrays
/// of any `Decodable` type. Handles date decoding using ISO8601 strategy.
///
/// ## Usage
/// ```swift
/// let transformer = ArrayTransformer<User>()
/// let users = try transformer.transform(jsonArrayData)
/// ```
///
/// ## Test Coverage
/// - Array decoding with multiple elements
/// - Empty array handling
/// - Date decoding strategy application
/// - Type-safe collection transformation
struct ArrayTransformer<Model: Decodable>: DataTransformer {
    func transform(_ data: Data) throws -> [Model] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Model].self, from: data)
    }
}

// MARK: - Format-Specific Transformers

/// Transforms CSV-formatted data into structured row collections.
///
/// Parses comma-separated value data into type-safe `Row` instances,
/// splitting by newlines and commas. Filters out empty lines.
///
/// ## CSV Format
/// ```
/// name,age,city
/// John,30,NYC
/// Jane,25,LA
/// ```
///
/// ## Output Structure
/// Each row becomes a `Row` instance with `values: [String]`.
///
/// ## Test Coverage
/// - Header and data row parsing
/// - Empty line filtering
/// - UTF-8 encoding validation
/// - Error handling for invalid encodings
struct CSVTransformer: DataTransformer {

    /// Represents a single parsed CSV row.
    struct Row: Equatable, Sendable {
        let values: [String]
    }

    func transform(_ data: Data) throws -> [Row] {
        guard let csv = String(data: data, encoding: .utf8) else {
            throw TransformerError.decodingFailed
        }

        return csv
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { line in
                Row(values: line.components(separatedBy: ","))
            }
    }

    // MARK: - Errors

    enum TransformerError: Error {
        case decodingFailed
    }
}
