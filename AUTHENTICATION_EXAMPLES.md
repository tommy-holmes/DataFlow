# Authentication Strategy Examples

## Overview

The `AuthenticationStrategy` protocol provides a flexible, extensible way to handle various authentication patterns in REST APIs. Each strategy is responsible for modifying the URLRequest with appropriate credentials and optionally handling unauthorized responses.

## Basic Usage

### No Authentication

```swift
let dataSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://api.example.com")!,
    authentication: .none
)
```

Or simply omit the parameter (default):

```swift
let dataSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://api.example.com")!
)
```

### Bearer Token

```swift
let dataSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://api.example.com")!,
    authentication: .bearerToken("your-token-here")
)
```

### Basic Authentication

```swift
let dataSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://api.example.com")!,
    authentication: .basic(
        username: "admin",
        password: "secret"
    )
)
```

### API Key in Header

```swift
let dataSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://api.example.com")!,
    authentication: .apiKey(
        "your-api-key",
        headerName: "X-API-Key"
    )
)
```

### API Key in Query Parameter

```swift
let dataSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://api.example.com")!,
    authentication: .apiKeyQuery(
        "your-api-key",
        parameterName: "api_key"
    )
)
```

### Custom Headers

```swift
let dataSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://api.example.com")!,
    authentication: .customHeaders([
        "X-Client-ID": "mobile-app",
        "X-API-Version": "2.0",
        "X-Request-ID": UUID().uuidString
    ])
)
```

### JWT with Automatic Refresh

```swift
let jwtProvider = JWTProvider(
    currentToken: {
        // Fetch current token from keychain/storage
        try await fetchStoredToken()
    },
    refreshToken: {
        // Perform refresh flow and store new token
        let newToken = try await performTokenRefresh()
        try await storeToken(newToken)
        return newToken
    }
)

let dataSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://api.example.com")!,
    authentication: .jwt(jwtProvider)
)
```

## Advanced: Composite Authentication

Combine multiple authentication strategies:

```swift
let dataSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://api.example.com")!,
    authentication: .composite(strategies: [
        .apiKey("api-key", headerName: "X-API-Key"),
        .customHeaders([
            "X-Client-ID": "ios-app",
            "X-App-Version": "1.2.3"
        ])
    ])
)
```

## Custom Authentication Strategy

Implement `AuthenticationStrategy` for custom auth patterns:

```swift
struct HMACAuthentication: AuthenticationStrategy {
    private let accessKey: String
    private let secretKey: String

    public init(accessKey: String, secretKey: String) {
        self.accessKey = accessKey
        self.secretKey = secretKey
    }

    public func authenticate(_ request: inout URLRequest) async throws {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? ""

        let stringToSign = "\(method)\n\(path)\n\(timestamp)"
        let signature = try hmacSHA256(key: secretKey, message: stringToSign)

        request.setValue(accessKey, forHTTPHeaderField: "X-Access-Key")
        request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-Signature")
    }

    private func hmacSHA256(key: String, message: String) throws -> String {
        // Implementation of HMAC-SHA256 signing
        // ...
    }
}

// Add a protocol extension for enum-like syntax (optional)
public extension AuthenticationStrategy where Self == HMACAuthentication {
    static func hmac(accessKey: String, secretKey: String) -> Self {
        HMACAuthentication(accessKey: accessKey, secretKey: secretKey)
    }
}

// Usage with direct initializer
let dataSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://api.example.com")!,
    authentication: HMACAuthentication(
        accessKey: "AKIAIOSFODNN7EXAMPLE",
        secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    )
)

// Or with the enum-like syntax
let dataSource2 = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://api.example.com")!,
    authentication: .hmac(
        accessKey: "AKIAIOSFODNN7EXAMPLE",
        secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    )
)
```

## OAuth 2.0 Client Credentials Flow

```swift
actor OAuthTokenManager {
    private var cachedToken: String?
    private var tokenExpiration: Date?

    func getToken(clientId: String, clientSecret: String, tokenURL: URL) async throws -> String {
        if let token = cachedToken, let expiration = tokenExpiration, Date() < expiration {
            return token
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let credentials = "\(clientId):\(clientSecret)".data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")

        let body = "grant_type=client_credentials"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)

        cachedToken = response.accessToken
        tokenExpiration = Date().addingTimeInterval(TimeInterval(response.expiresIn - 60))

        return response.accessToken
    }

    struct TokenResponse: Codable {
        let accessToken: String
        let expiresIn: Int

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
        }
    }
}

struct OAuthClientCredentialsAuthentication: AuthenticationStrategy {
    private let tokenManager: OAuthTokenManager
    private let clientId: String
    private let clientSecret: String
    private let tokenURL: URL

    public init(clientId: String, clientSecret: String, tokenURL: URL) {
        self.tokenManager = OAuthTokenManager()
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.tokenURL = tokenURL
    }

    public func authenticate(_ request: inout URLRequest) async throws {
        let token = try await tokenManager.getToken(
            clientId: clientId,
            clientSecret: clientSecret,
            tokenURL: tokenURL
        )
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

// Add a protocol extension for enum-like syntax (optional)
public extension AuthenticationStrategy where Self == OAuthClientCredentialsAuthentication {
    static func oauthClientCredentials(
        clientId: String,
        clientSecret: String,
        tokenURL: URL
    ) -> Self {
        OAuthClientCredentialsAuthentication(
            clientId: clientId,
            clientSecret: clientSecret,
            tokenURL: tokenURL
        )
    }
}

// Usage with direct initializer
let dataSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://api.example.com")!,
    authentication: OAuthClientCredentialsAuthentication(
        clientId: "your-client-id",
        clientSecret: "your-client-secret",
        tokenURL: URL(string: "https://auth.example.com/oauth/token")!
    )
)

// Or with the enum-like syntax
let dataSource2 = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://api.example.com")!,
    authentication: .oauthClientCredentials(
        clientId: "your-client-id",
        clientSecret: "your-client-secret",
        tokenURL: URL(string: "https://auth.example.com/oauth/token")!
    )
)
```

## Testing

All strategies are `Sendable` and can be easily mocked:

```swift
struct MockAuthentication: AuthenticationStrategy {
    public init() {}

    public func authenticate(_ request: inout URLRequest) async throws {
        request.setValue("MockToken", forHTTPHeaderField: "Authorization")
    }
}

// Add a protocol extension for enum-like syntax in tests (optional)
public extension AuthenticationStrategy where Self == MockAuthentication {
    static func mock() -> Self {
        MockAuthentication()
    }
}

// Usage with direct initializer
let testDataSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://test.example.com")!,
    authentication: MockAuthentication()
)

// Or with enum-like syntax
let testDataSource2 = DataSource<RESTRequest>.liveAPI(
    baseUrl: URL(string: "https://test.example.com")!,
    authentication: .mock()
)
```

## Best Practices

### Use Enum-Like Syntax for Clean Code

The enum-like syntax (`.bearerToken()`, `.basic()`, etc.) is the recommended approach when the type is constrained to `any AuthenticationStrategy`:

```swift
// ✅ Preferred - clean and concise
let dataSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: url,
    authentication: .bearerToken("token")
)
```

### Direct Initializers for Flexibility

Direct initializers are also available if you need more explicit control or want to build strategies dynamically:

```swift
// ✅ Also valid - explicit and flexible
let token = "your-token"
let auth = BearerTokenAuthentication(token: token)
let dataSource = DataSource<RESTRequest>.liveAPI(
    baseUrl: url,
    authentication: auth
)
```

### Creating Custom Strategies

When creating custom authentication strategies, provide both:

1. A public initializer for flexibility
2. A protocol extension for enum-like syntax

This makes your custom auth types consistent with the built-in strategies:

```swift
struct CustomAuth: AuthenticationStrategy {
    public init(...) { ... }
    public func authenticate(...) { ... }
}

public extension AuthenticationStrategy where Self == CustomAuth {
    static func custom(...) -> Self {
        CustomAuth(...)
    }
}

// Users can then use:
.liveAPI(baseUrl: url, authentication: .custom(...))
```
