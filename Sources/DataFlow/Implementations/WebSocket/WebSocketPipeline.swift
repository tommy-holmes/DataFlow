import Foundation

public struct WebSocketPipeline<D: Decodable>: ModelProvider {
    public let request: WebSocketRequest
    public var source: DataSource<WebSocketRequest>
    public var transformer: WebSocketTransformer<D>

    public init(request: WebSocketRequest, source: DataSource<WebSocketRequest>) {
        self.request = request
        self.source = source
        self.transformer = WebSocketTransformer<D>()
    }

    public func loadData() async throws -> D {
        let data = try await source.fetch(request)
        return try transformer.transform(data)
    }
}

public extension DataSource where Type == WebSocketRequest {
    static func liveWebSocket() -> Self {
        DataSource { request in
            // Simplified implementation that collects first message
            // For production use, implement proper WebSocket handling
            let session = URLSession(configuration: .default)
            let webSocketTask = session.webSocketTask(with: request.url)

            return try await withCheckedThrowingContinuation { continuation in
                webSocketTask.resume()

                webSocketTask.receive { result in
                    switch result {
                    case let .success(message):
                        switch message {
                        case let .data(data):
                            webSocketTask.cancel(with: .goingAway, reason: nil)
                            continuation.resume(returning: data)
                        case let .string(text):
                            webSocketTask.cancel(with: .goingAway, reason: nil)
                            if let data = text.data(using: .utf8) {
                                continuation.resume(returning: data)
                            } else {
                                continuation.resume(throwing: WebSocketError.noDataReceived)
                            }
                        @unknown default:
                            webSocketTask.cancel(with: .goingAway, reason: nil)
                            continuation.resume(throwing: WebSocketError.noDataReceived)
                        }
                    case let .failure(error):
                        webSocketTask.cancel(with: .goingAway, reason: nil)
                        continuation.resume(throwing: WebSocketError.connectionFailed(error))
                    }
                }
            }
        }
    }
}

// Actor to safely manage mutable state in async closures
private actor WebSocketState {
    private var _data: Data?
    private var _count: Int = 0

    func setData(_ data: Data) {
        self._data = data
    }

    func getData() -> Data? {
        return self._data
    }

    func incrementAndCheckComplete(maxMessages: Int) -> Bool {
        self._count += 1
        return self._count >= maxMessages
    }
}

public enum WebSocketError: Error, Sendable {
    case connectionFailed(Error)
    case noDataReceived
    case invalidURL
}
