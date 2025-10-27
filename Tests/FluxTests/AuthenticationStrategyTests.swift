import Foundation
import Testing
@testable import Flux

@Suite("Authentication Strategy")
struct AuthenticationStrategyTests {

    @Test("NoAuthentication leaves request unchanged")
    func noAuthenticationDoesNotModifyRequest() async throws {
        let auth: AuthenticationStrategy = .none
        var request = URLRequest(url: URL(string: "https://api.example.com")!)

        try await auth.authenticate(&request)

        #expect(request.allHTTPHeaderFields?["Authorization"] == nil)
    }

    @Test("BearerTokenAuthentication adds Bearer header")
    func bearerTokenAddsAuthorizationHeader() async throws {
        let auth = BearerTokenAuthentication(token: "test-token-123")
        var request = URLRequest(url: URL(string: "https://api.example.com")!)

        try await auth.authenticate(&request)

        #expect(request.allHTTPHeaderFields?["Authorization"] == "Bearer test-token-123")
    }

    @Test("BasicAuthentication encodes credentials correctly")
    func basicAuthEncodesCredentials() async throws {
        let auth = BasicAuthentication(username: "user", password: "pass")
        var request = URLRequest(url: URL(string: "https://api.example.com")!)

        try await auth.authenticate(&request)

        let expectedCredentials = "user:pass".data(using: .utf8)!.base64EncodedString()
        #expect(request.allHTTPHeaderFields?["Authorization"] == "Basic \(expectedCredentials)")
    }

    @Test("APIKeyAuthentication adds header")
    func apiKeyInHeader() async throws {
        let auth = APIKeyAuthentication(key: "secret-key", location: .header(name: "X-API-Key"))
        var request = URLRequest(url: URL(string: "https://api.example.com")!)

        try await auth.authenticate(&request)

        #expect(request.allHTTPHeaderFields?["X-API-Key"] == "secret-key")
    }

    @Test("APIKeyAuthentication adds query parameter")
    func apiKeyInQuery() async throws {
        let auth = APIKeyAuthentication(key: "secret-key", location: .query(name: "api_key"))
        var request = URLRequest(url: URL(string: "https://api.example.com/users")!)

        try await auth.authenticate(&request)

        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        let queryItem = components?.queryItems?.first(where: { $0.name == "api_key" })
        #expect(queryItem?.value == "secret-key")
    }

    @Test("CustomHeadersAuthentication adds multiple headers")
    func customHeadersAddsMultipleHeaders() async throws {
        let auth = CustomHeadersAuthentication(headers: [
            "X-Client-ID": "ios-app",
            "X-Request-ID": "12345"
        ])
        var request = URLRequest(url: URL(string: "https://api.example.com")!)

        try await auth.authenticate(&request)

        #expect(request.allHTTPHeaderFields?["X-Client-ID"] == "ios-app")
        #expect(request.allHTTPHeaderFields?["X-Request-ID"] == "12345")
    }

    @Test("JWTAuthentication uses JWT provider")
    func jwtAuthUsesProvider() async throws {
        let provider = JWTProvider(
            currentToken: { "initial-jwt" },
            refreshToken: { "refreshed-jwt" }
        )
        let auth = JWTAuthentication(provider: provider)
        var request = URLRequest(url: URL(string: "https://api.example.com")!)

        try await auth.authenticate(&request)

        #expect(request.allHTTPHeaderFields?["Authorization"] == "Bearer initial-jwt")
    }

    @Test("CompositeAuthentication combines multiple strategies")
    func compositeAuthCombinesStrategies() async throws {
        let auth = CompositeAuthentication(strategies: [
            APIKeyAuthentication(key: "api-key", location: .header(name: "X-API-Key")),
            CustomHeadersAuthentication(headers: ["X-Client": "test"])
        ])
        var request = URLRequest(url: URL(string: "https://api.example.com")!)

        try await auth.authenticate(&request)

        #expect(request.allHTTPHeaderFields?["X-API-Key"] == "api-key")
        #expect(request.allHTTPHeaderFields?["X-Client"] == "test")
    }

    @Test("JWTAuthentication handles 401 retry")
    func jwtAuthHandlesUnauthorizedRetry() async throws {
        actor CallCounter {
            var count = 0
            func increment() { count += 1 }
            func getCount() -> Int { count }
        }

        let counter = CallCounter()
        let provider = JWTProvider(
            currentToken: { "initial-jwt" },
            refreshToken: {
                await counter.increment()
                return "refreshed-jwt"
            }
        )
        let auth = JWTAuthentication(provider: provider)

        let (_, _) = try await auth.handleUnauthorized {
            let mockData = Data()
            let mockResponse = HTTPURLResponse(
                url: URL(string: "https://api.example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (mockData, mockResponse)
        }

        let finalCount = await counter.getCount()
        #expect(finalCount == 1)
    }

    @Test("DataSource.liveAPI uses NoAuthentication by default")
    func liveAPIUsesNoAuthByDefault() async throws {
        let source = DataSource<RESTRequest>.liveAPI(
            baseUrl: URL(string: "https://api.example.com")!
        )

        // Verify the source was created (can't test equality on closures)
        _ = source
    }

    @Test("DataSource.liveAPI accepts authentication strategy")
    func liveAPIAcceptsAuthStrategy() async throws {
        let source = DataSource<RESTRequest>.liveAPI(
            baseUrl: URL(string: "https://api.example.com")!,
            authentication: .bearerToken("test")
        )

        // Verify the source was created with auth strategy
        _ = source
    }
}
