import Foundation

nonisolated
struct ProductReview: Identifiable, Hashable, Sendable {
    let id: Int
    let rating: Int
    let comment: String
    let date: Date
    let reviewerName: String
}

nonisolated
struct Product: Identifiable, Hashable, Sendable {
    typealias ID = Int
    let id: ID
    let title: String
    let description: String
    let category: String
    let price: Decimal
    let rating: Double
    let stock: Int
    let thumbnailURL: URL?
    let imageURLs: [URL]
    let reviews: [ProductReview]

    var snapshot: ProductSnapshot {
        ProductSnapshot(id: id, title: title, price: price, thumbnailURL: thumbnailURL)
    }
}
