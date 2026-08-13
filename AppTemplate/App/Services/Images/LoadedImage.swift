import Foundation

nonisolated
struct LoadedImage: Equatable, Sendable {
    let data: Data
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int
}
