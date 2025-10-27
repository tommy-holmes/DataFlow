import os
import Foundation

private extension Logger {
    static let networking = Logger(subsystem: "com.ceo", category: "networking")
    static let auth = Logger(subsystem: "com.ceo", category: "auth")
}

public extension DataSource
where Type == RESTRequest {
    typealias JWT = String
    
    enum HTTPError: Error {
        case badStatus(code: Int, data: Data?)
        case invalidResponse
    }
    
    enum AuthProvider: Sendable {
        case none, bearerToken(String), jwtProvider(JWTProvider)
    }
    
    static func liveAPI(
        baseUrl: URL,
        authProvider: AuthProvider
    ) -> Self {
        DataSource { request in
            let url = baseUrl
                .appending(path: request.path)
                .appending(queryItems: request.queryItems)
            
            func makeRequest(with token: String?) -> URLRequest {
                var req = URLRequest(url: url)
                req.httpMethod = request.method.rawValue.uppercased()
                req.httpBody = request.body
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let token {
                    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                return req
            }
            func perform(_ token: String?) async throws -> (Data, HTTPURLResponse) {
                let request = makeRequest(with: token)
                
                Logger.networking.debug(
                    "Encoded body: \(request.httpBody?.jsonPrettyPrinted ?? "No body data", privacy: .private(mask: .hash))"
                )
                
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw HTTPError.invalidResponse
                }
                
                Logger.networking.debug(
                    "Received data from live: \(request.url?.absoluteString ?? "", privacy: .private(mask: .hash)):\n\(data.jsonPrettyPrinted, privacy: .private(mask: .hash))"
                )
                return (data, http)
            }
            func handleAuth(for provider: AuthProvider) async throws -> (Data, HTTPURLResponse) {
                switch provider {
                case .none: return try await perform(nil)
                case let .bearerToken(token): return try await perform(token)
                    
                case let .jwtProvider(jwtProvider):
                    let initialToken = try await jwtProvider.currentToken()
                    Logger.auth.debug("Acquired JWT from provider for: \(request.path, privacy: .private(mask: .hash))")
                    let (data, http) = try await perform(initialToken)
                    
                    if http.statusCode == 401 {
                        Logger.auth.warning("401 Unauthorized for: \(request.path, privacy: .private(mask: .hash)). Attempting JWT refresh and single retry.")
                        let refreshedToken = try await jwtProvider.refreshToken()
                        
                        Logger.auth.debug("JWT refreshed. Retrying request for: \(request.path, privacy: .private(mask: .hash))")
                        return try await perform(refreshedToken)
                    }
                    return (data, http)
                }
            }
            
            let (data, http) = try await handleAuth(for: authProvider)
            
            guard (200..<300).contains(http.statusCode) else {
                throw HTTPError
                    .badStatus(code: http.statusCode, data: data)
            }
            return data
        }
    }
    static var noop: Self {
        DataSource { _ in Data() }
    }
}
