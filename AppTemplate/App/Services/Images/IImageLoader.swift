import Foundation

nonisolated
protocol IImageLoader: Sendable {
    func load(_ url: URL, policy: ImageLoadPolicy) async throws -> LoadedImage
}
