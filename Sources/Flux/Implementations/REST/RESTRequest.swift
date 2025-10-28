import Foundation

public struct RESTRequest: Sendable {
    public let path: String
    public let queryItems: [URLQueryItem]
    public let headers: [Header]
    public let method: Method
    public let body: Data?

    public init(
        path: String,
        method: Method = .get,
        queryItems: [URLQueryItem] = [],
        headers: [Header] = [
            .contentType("application/json"),
        ],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
    }
}

public extension RESTRequest {
    enum Method: String, Sendable {
        case get, post, put, patch, delete
    }
}
