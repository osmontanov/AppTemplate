import Foundation

nonisolated
enum ProductRepositoryError: Error, Equatable, Sendable {
    case invalidQuery
    case invalidData
}

nonisolated
struct ProductMapper: Sendable {
    func categories(_ values: [ProductCategoryDTO]) throws -> [ProductCategory] {
        var seen: Set<String> = []
        var result: [ProductCategory] = []
        for value in values {
            let slug = value.slug.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !slug.isEmpty, !name.isEmpty else {
                throw ProductRepositoryError.invalidData
            }
            guard seen.insert(slug).inserted else { continue }
            result.append(ProductCategory(slug: slug, name: name))
        }
        return result.sorted { $0.slug < $1.slug }
    }

    func page(_ value: ProductPageDTO) throws -> ProductPage {
        guard value.total >= 0, value.skip >= 0, value.limit > 0 else {
            throw ProductRepositoryError.invalidData
        }
        return ProductPage(
            products: try value.products.map(product),
            total: value.total,
            skip: value.skip,
            limit: value.limit
        )
    }

    func product(_ value: ProductDTO) throws -> Product {
        let title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = value.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = value.category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.id > 0,
              !title.isEmpty,
              !description.isEmpty,
              !category.isEmpty,
              value.price.isFinite,
              value.price >= 0,
              value.rating.isFinite,
              (0...5).contains(value.rating),
              value.stock >= 0
        else {
            throw ProductRepositoryError.invalidData
        }
        let reviews = try value.reviews.enumerated().map { offset, review in
            let comment = review.comment.trimmingCharacters(in: .whitespacesAndNewlines)
            let reviewerName = review.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (1...5).contains(review.rating),
                  !comment.isEmpty,
                  !reviewerName.isEmpty
            else {
                throw ProductRepositoryError.invalidData
            }
            return ProductReview(
                id: offset + 1,
                rating: review.rating,
                comment: comment,
                date: review.date,
                reviewerName: reviewerName
            )
        }
        return Product(
            id: value.id,
            title: title,
            description: description,
            category: category,
            price: value.price,
            rating: value.rating,
            stock: value.stock,
            thumbnailURL: value.thumbnail,
            imageURLs: value.images,
            reviews: reviews
        )
    }
}

actor ProductRepository: IProductRepository {
    private let remote: any IRemoteService
    private let mapper: ProductMapper

    init(remote: any IRemoteService, mapper: ProductMapper = ProductMapper()) {
        self.remote = remote
        self.mapper = mapper
    }

    func categories() async throws -> [ProductCategory] {
        try mapper.categories(await remote.categories())
    }

    func page(_ query: ProductQuery) async throws -> ProductPage {
        let query = try Self.validated(query)
        let value = try await remote.products(ProductPageRequest(
            mode: query.mode,
            sort: query.sort,
            limit: query.limit,
            skip: query.skip
        ))
        return try mapper.page(value)
    }

    func product(id: Product.ID) async throws -> Product {
        guard id > 0 else { throw ProductRepositoryError.invalidQuery }
        return try mapper.product(await remote.product(id: id))
    }

    func related(to product: Product, limit: Int) async throws -> [Product] {
        guard limit > 0 else { return [] }
        let values = try await page(ProductQuery(
            mode: .category(product.category),
            sort: nil,
            limit: min(100, limit + 20),
            skip: 0
        )).products
        var seen: Set<Int> = []
        return Array(values
            .filter { $0.id != product.id && seen.insert($0.id).inserted }
            .sorted { $0.id < $1.id }
            .prefix(limit))
    }

    private nonisolated static func validated(_ query: ProductQuery) throws -> ProductQuery {
        guard (1...100).contains(query.limit), query.skip >= 0 else {
            throw ProductRepositoryError.invalidQuery
        }
        let mode: ProductQueryMode
        switch query.mode {
        case .all:
            mode = .all
        case let .search(value):
            let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { throw ProductRepositoryError.invalidQuery }
            mode = .search(value)
        case let .category(value):
            let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { throw ProductRepositoryError.invalidQuery }
            mode = .category(value)
        }
        guard query.sort == nil || mode == .all else {
            throw ProductRepositoryError.invalidQuery
        }
        return ProductQuery(mode: mode, sort: query.sort, limit: query.limit, skip: query.skip)
    }
}
