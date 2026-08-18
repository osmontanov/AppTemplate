import Foundation

nonisolated
protocol IImageBytesLoading: Sendable {
    func bytes(for url: URL) async throws(ImageServiceError) -> ImageBytes
}
