import Foundation

public struct WebSocketTransformer<Model: Decodable>: DataTransformer {
    public init() { }

    public func transform(_ data: Data) throws -> Model {
        try JSONDecoder().decode(Model.self, from: data)
    }
}
