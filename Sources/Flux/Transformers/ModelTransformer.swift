import Foundation

public struct ModelTransformer<Model: Encodable>: DataTransformer {
    
    public init() { }
    
    public func transform(_ data: Model) throws -> Data {
        try Self.encoder.encode(data)
    }
}

private extension ModelTransformer {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        return encoder
    }
}
