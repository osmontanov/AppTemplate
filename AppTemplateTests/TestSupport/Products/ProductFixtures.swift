import Foundation
@testable import AppTemplate

nonisolated extension Product {
    static func fixture(
        id: Int = 1,
        title: String = "Product",
        category: String = "phones",
        price: Decimal = 12.50,
        thumbnailURL: URL? = URL(string: "https://cdn.dummyjson.com/product.png"),
        reviews: [ProductReview] = []
    ) -> Product {
        Product(
            id: id,
            title: title,
            description: "Description",
            category: category,
            price: price,
            rating: 4.5,
            stock: 7,
            thumbnailURL: thumbnailURL,
            imageURLs: [URL(string: "https://cdn.dummyjson.com/product-large.png")!],
            reviews: reviews
        )
    }
}

nonisolated extension ProductDTO {
    static func fixture(
        id: Int = 1,
        title: String = "Product",
        category: String = "phones",
        price: Decimal = 12.50,
        reviews: [ProductReviewDTO] = []
    ) -> ProductDTO {
        ProductDTO(
            id: id,
            title: title,
            description: "Description",
            category: category,
            price: price,
            rating: 4.5,
            stock: 7,
            brand: "Brand",
            availabilityStatus: "In Stock",
            reviews: reviews,
            images: [URL(string: "https://cdn.dummyjson.com/product-large.png")!],
            thumbnail: URL(string: "https://cdn.dummyjson.com/product.png")
        )
    }
}

nonisolated extension CartAggregate {
    static func fixture(
        revision: Int64 = 1,
        products: [Product] = [.fixture()]
    ) -> CartAggregate {
        CartAggregate(
            id: CartAggregate.singletonID,
            revision: revision,
            lines: products.map { CartLine(product: $0.snapshot, quantity: 1) }
        )
    }
}
