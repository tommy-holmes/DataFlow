public extension RESTRequest {
    struct Header: Sendable {
        let field: String
        let value: String
        
        public init(field: String, value: String) {
            self.field = field
            self.value = value
        }
    }
}

public extension RESTRequest.Header {
    // MARK: - Content Negotiation
    static func contentType(_ contentType: String) -> Self {
        Self(field: "Content-Type", value: contentType)
    }
    static func accept(_ value: String) -> Self {
        Self(field: "Accept", value: value)
    }
    static func acceptLanguage(_ value: String) -> Self {
        Self(field: "Accept-Language", value: value)
    }
    static func acceptEncoding(_ value: String) -> Self {
        Self(field: "Accept-Encoding", value: value)
    }
    
    // MARK: - Authorization
    static func authorization(_ value: String) -> Self {
        Self(field: "Authorization", value: value)
    }
    static func bearer(_ token: String) -> Self {
        Self(field: "Authorization", value: "Bearer \(token)")
    }
    
    // MARK: - Caching
    static func cacheControl(_ value: String) -> Self {
        Self(field: "Cache-Control", value: value)
    }
    static func pragma(_ value: String) -> Self {
        Self(field: "Pragma", value: value)
    }
    static func expires(_ value: String) -> Self {
        Self(field: "Expires", value: value)
    }
    static func ifNoneMatch(_ value: String) -> Self {
        Self(field: "If-None-Match", value: value)
    }
    static func ifModifiedSince(_ value: String) -> Self {
        Self(field: "If-Modified-Since", value: value)
    }
    static func etag(_ value: String) -> Self {
        Self(field: "ETag", value: value)
    }
    
    // MARK: - Request Context
    static func userAgent(_ value: String) -> Self {
        Self(field: "User-Agent", value: value)
    }
    static func referer(_ value: String) -> Self { // Note: spelled "Referer" per spec
        Self(field: "Referer", value: value)
    }
    static func origin(_ value: String) -> Self {
        Self(field: "Origin", value: value)
    }
    static func host(_ value: String) -> Self {
        Self(field: "Host", value: value)
    }
    static func connection(_ value: String) -> Self {
        Self(field: "Connection", value: value)
    }
    static func upgradeInsecureRequests(_ value: String = "1") -> Self {
        Self(field: "Upgrade-Insecure-Requests", value: value)
    }
    static func xRequestedWith(_ value: String = "XMLHttpRequest") -> Self {
        Self(field: "X-Requested-With", value: value)
    }
    
    // MARK: - Content Metadata
    static func contentLength(_ length: Int) -> Self {
        Self(field: "Content-Length", value: String(length))
    }
    static func contentEncoding(_ value: String) -> Self {
        Self(field: "Content-Encoding", value: value)
    }
    static func contentLanguage(_ value: String) -> Self {
        Self(field: "Content-Language", value: value)
    }
    static func contentDisposition(_ value: String) -> Self {
        Self(field: "Content-Disposition", value: value)
    }
    static func contentMD5(_ value: String) -> Self {
        Self(field: "Content-MD5", value: value)
    }
    static func range(_ value: String) -> Self {
        Self(field: "Range", value: value)
    }
    
    // MARK: - Conditional Requests
    static func ifMatch(_ value: String) -> Self {
        Self(field: "If-Match", value: value)
    }
    static func ifUnmodifiedSince(_ value: String) -> Self {
        Self(field: "If-Unmodified-Since", value: value)
    }
    
    // MARK: - Cookies
    static func cookie(_ value: String) -> Self {
        Self(field: "Cookie", value: value)
    }
    static func setCookie(_ value: String) -> Self {
        Self(field: "Set-Cookie", value: value)
    }
    
    // MARK: - CORS
    static func accessControlRequestMethod(_ value: String) -> Self {
        Self(field: "Access-Control-Request-Method", value: value)
    }
    static func accessControlRequestHeaders(_ value: String) -> Self {
        Self(field: "Access-Control-Request-Headers", value: value)
    }
    
    // MARK: - Misc
    static func dnt(_ value: String) -> Self { // Do Not Track
        Self(field: "DNT", value: value)
    }
    static func xApiKey(_ value: String) -> Self {
        Self(field: "X-API-Key", value: value)
    }
    static func xCsrfToken(_ value: String) -> Self {
        Self(field: "X-CSRF-Token", value: value)
    }
    
    // MARK: - Generic helper for custom headers
    static func custom(_ field: String, _ value: String) -> Self {
        Self(field: field, value: value)
    }
}
