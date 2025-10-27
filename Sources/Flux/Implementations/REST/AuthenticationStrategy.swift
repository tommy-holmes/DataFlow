import Foundation

public protocol AuthenticationStrategy: Sendable {
    func authenticate(_ request: inout URLRequest) async throws
    func handleUnauthorized(
        retry: @Sendable () async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse)
}

public extension AuthenticationStrategy {
    func handleUnauthorized(
        retry: @Sendable () async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        throw URLError(.userAuthenticationRequired)
    }
}

// MARK: - No Authentication

public struct NoAuthentication: AuthenticationStrategy {
    public func authenticate(_ request: inout URLRequest) async throws {}
}

public extension AuthenticationStrategy
where Self == NoAuthentication {
    static var none: Self { NoAuthentication() }
}

// MARK: - Bearer Token

public struct BearerTokenAuthentication: AuthenticationStrategy {
    let token: String

    public func authenticate(_ request: inout URLRequest) async throws {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

public extension AuthenticationStrategy
where Self == BearerTokenAuthentication {
    static func bearerToken(_ token: String) -> Self {
        BearerTokenAuthentication(token: token)
    }
}

// MARK: - Basic Authentication

public struct BasicAuthentication: AuthenticationStrategy {
    let username: String
    let password: String

    public func authenticate(_ request: inout URLRequest) async throws {
        let credentials = "\(username):\(password)"
        guard let data = credentials.data(using: .utf8) else {
            throw AuthError.failedToAcquireToken
        }
        let base64 = data.base64EncodedString()
        request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
    }
}

public extension AuthenticationStrategy
where Self == BasicAuthentication {
    static func basic(username: String, password: String) -> Self {
        BasicAuthentication(username: username, password: password)
    }
}

// MARK: - API Key Authentication

public struct APIKeyAuthentication: AuthenticationStrategy {
    let key: String
    let location: Location

    public enum Location: Sendable {
        case header(name: String)
        case query(name: String)
    }

    public func authenticate(_ request: inout URLRequest) async throws {
        switch location {
        case .header(let name):
            request.setValue(key, forHTTPHeaderField: name)
        case .query(let name):
            guard var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false) else {
                throw AuthError.failedToAcquireToken
            }
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: name, value: key))
            components.queryItems = items
            request.url = components.url
        }
    }
}

public extension AuthenticationStrategy
where Self == APIKeyAuthentication {
    static func apiKey(_ key: String, headerName: String) -> Self {
        APIKeyAuthentication(key: key, location: .header(name: headerName))
    }
    static func apiKeyQuery(_ key: String, parameterName: String) -> Self {
        APIKeyAuthentication(key: key, location: .query(name: parameterName))
    }
}

// MARK: - Custom Headers

public struct CustomHeadersAuthentication: AuthenticationStrategy {
    let headers: [String: String]

    public func authenticate(_ request: inout URLRequest) async throws {
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
}

public extension AuthenticationStrategy
where Self == CustomHeadersAuthentication {
    static func customHeaders(_ headers: [String: String]) -> Self {
        CustomHeadersAuthentication(headers: headers)
    }
}

// MARK: - JWT with Refresh

public struct JWTAuthentication: AuthenticationStrategy {
    let provider: JWTProvider

    public func authenticate(_ request: inout URLRequest) async throws {
        let token = try await provider.currentToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    public func handleUnauthorized(
        retry: @Sendable () async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        _ = try await provider.refreshToken()
        return try await retry()
    }
}

public extension AuthenticationStrategy
where Self == JWTAuthentication {
    static func jwt(_ provider: JWTProvider) -> Self {
        JWTAuthentication(provider: provider)
    }
}

// MARK: - Composite Authentication

public struct CompositeAuthentication: AuthenticationStrategy {
    let strategies: [any AuthenticationStrategy]

    public func authenticate(_ request: inout URLRequest) async throws {
        for strategy in strategies {
            try await strategy.authenticate(&request)
        }
    }

    public func handleUnauthorized(
        retry: @Sendable () async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        for strategy in strategies {
            do {
                return try await strategy.handleUnauthorized(retry: retry)
            } catch URLError.userAuthenticationRequired {
                continue
            }
        }
        throw URLError(.userAuthenticationRequired)
    }
}

public extension AuthenticationStrategy
where Self == CompositeAuthentication {
    static func composite(strategies: [any AuthenticationStrategy]) -> Self {
        CompositeAuthentication(strategies: strategies)
    }
}
