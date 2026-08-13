import Foundation

nonisolated
struct ProductCategoryDTO: Codable, Equatable, Sendable {
    let slug: String
    let name: String
    let url: URL
}
