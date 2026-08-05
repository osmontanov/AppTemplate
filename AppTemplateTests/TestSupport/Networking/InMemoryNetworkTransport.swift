import Foundation
@testable import AppTemplate

actor InMemoryNetworkTransport: NetworkTransport {
    typealias Handler = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let handler: Handler
    private var requests: [URLRequest] = []

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return try await handler(request)
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}
