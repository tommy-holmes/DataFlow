import Foundation

public struct WebSocketRequest: Sendable {
    public let url: URL
    public let headers: [String: String]
    public let messageCount: Int?

    public init(
        url: URL,
        headers: [String: String] = [:],
        messageCount: Int? = nil
    ) {
        self.url = url
        self.headers = headers
        self.messageCount = messageCount
    }
}
