import Foundation

public struct Request: Sendable {
    let path: String
    let queryItems: [URLQueryItem]
    let method: Method
    let body: Data?
    
    public init(
        path: String,
        method: Method = .get,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
    }
}

public extension Request {
    enum Method: String, Sendable {
        case get, post, put, patch, delete
    }
}
