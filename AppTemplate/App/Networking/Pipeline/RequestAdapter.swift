import Foundation

nonisolated
protocol RequestAdapter: Sendable {
    func adapt(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async throws -> URLRequest
}
