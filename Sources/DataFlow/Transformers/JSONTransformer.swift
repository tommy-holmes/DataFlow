import Foundation

public struct JSONTransformer<Model: Decodable>: DataTransformer {
    
    public init() { }
    
    public func transform(_ data: Data) throws -> Model {
        try Self.decoder.decode(Model.self, from: data)
    }
}

private extension JSONTransformer {
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return decoder
    }
}
