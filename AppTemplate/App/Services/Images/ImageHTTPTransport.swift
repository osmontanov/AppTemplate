import Foundation

nonisolated
struct ImageHTTPResponse: Sendable {
    let finalURL: URL
    let statusCode: Int
    let mimeType: String?
    let data: Data
}

nonisolated
protocol IImageHTTPTransport: Sendable {
    func fetch(_ url: URL, policy: ImageLoadPolicy) async throws -> ImageHTTPResponse
}
