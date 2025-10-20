public enum AuthError: Error {
    case noSession, failedToAcquireToken, other(Error)
}

public struct JWTProvider: Sendable {
    public typealias JWT = String
    public typealias FetchTokenFunction = @Sendable () async throws(AuthError) -> JWT
    
    private let _currentToken: FetchTokenFunction
    private let _refreshToken: FetchTokenFunction
    
    public init(
        currentToken: @escaping FetchTokenFunction,
        refreshToken: @escaping FetchTokenFunction
    ) {
        self._currentToken = currentToken
        self._refreshToken = refreshToken
    }
    
    public func currentToken() async throws(AuthError) -> JWT {
        try await _currentToken()
    }
    public func refreshToken() async throws(AuthError) -> JWT {
        try await _refreshToken()
    }
}

public extension JWTProvider {
    static let mock = JWTProvider(
        currentToken: { "MockJWT" },
        refreshToken: { "MockJWT" }
    )
}
