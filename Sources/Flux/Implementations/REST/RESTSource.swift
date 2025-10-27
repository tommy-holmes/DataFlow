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

    static func liveAPI(
        baseUrl: URL,
        authentication: any AuthenticationStrategy = .none
    ) -> Self {
        DataSource { request in
            let url = baseUrl
                .appending(path: request.path)
                .appending(queryItems: request.queryItems)

            @Sendable func makeRequest() async throws -> URLRequest {
                var req = URLRequest(url: url)
                req.httpMethod = request.method.rawValue.uppercased()
                req.httpBody = request.body
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                try await authentication.authenticate(&req)
                return req
            }

            @Sendable func perform() async throws -> (Data, HTTPURLResponse) {
                let request = try await makeRequest()

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

            let (data, http) = try await perform()

            if http.statusCode == 401 {
                Logger.auth.warning("401 Unauthorized for: \(request.path, privacy: .private(mask: .hash)). Attempting auth refresh and single retry.")
                let (retryData, retryHttp) = try await authentication.handleUnauthorized(retry: perform)
                guard (200..<300).contains(retryHttp.statusCode) else {
                    throw HTTPError.badStatus(code: retryHttp.statusCode, data: retryData)
                }
                return retryData
            }

            guard (200..<300).contains(http.statusCode) else {
                throw HTTPError.badStatus(code: http.statusCode, data: data)
            }
            return data
        }
    }
    static var noop: Self {
        DataSource { _ in Data() }
    }
}
