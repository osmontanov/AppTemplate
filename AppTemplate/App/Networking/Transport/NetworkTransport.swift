import Foundation

nonisolated
protocol NetworkTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}
