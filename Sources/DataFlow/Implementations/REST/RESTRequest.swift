import Foundation

public struct RESTRequest: Requestable {
    public let path: String
    public let queryItems: [URLQueryItem]
    public let method: Method
    public let body: Data?
    
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

public extension RESTRequest {
    enum Method: String, Sendable {
        case get, post, put, patch, delete
    }
}
