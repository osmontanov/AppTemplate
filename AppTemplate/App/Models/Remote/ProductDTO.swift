import Foundation

nonisolated
struct ProductReviewDTO: Codable, Equatable, Sendable {
    let rating: Int
    let comment: String
    let date: Date
    let reviewerName: String
}

nonisolated
struct ProductDTO: Codable, Equatable, Sendable {
    let id: Int
    let title: String
    let description: String
    let category: String
    let price: Decimal
    let rating: Double
    let stock: Int
    let brand: String?
    let availabilityStatus: String?
    let reviews: [ProductReviewDTO]
    let images: [URL]
    let thumbnail: URL?
}
