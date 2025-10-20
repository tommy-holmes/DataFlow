public enum AuthError: Error {
    case noSession, failedToAcquireToken, other(Error)
}

public protocol JWTProvider: Sendable {
    typealias JWT = String
    
    func currentToken() async throws(AuthError) -> JWT
    func refreshToken() async throws(AuthError) -> JWT
}

public struct MockJWTProvider: JWTProvider {
    
    public init() { }
    
    public func currentToken() async throws(AuthError) -> JWT {
        "MockJWT"
    }
    public func refreshToken() async throws(AuthError) -> JWT {
        "MockJWT"
    }
}
