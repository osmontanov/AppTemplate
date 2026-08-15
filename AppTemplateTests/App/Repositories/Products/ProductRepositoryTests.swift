import Foundation
import Testing
@testable import AppTemplate

struct ProductRepositoryTests {
    @Test
    func snapshotCopiesOnlyPersistenceFields() {
        let product = Product.fixture(id: 8, title: "Exact", price: 99.25)

        #expect(product.snapshot == ProductSnapshot(
            id: 8,
            title: "Exact",
            price: 99.25,
            thumbnailURL: URL(string: "https://cdn.dummyjson.com/product.png")
        ))
    }

    @Test
    func mapperKeepsReviewOrderWithStableOneBasedIDs() throws {
        let firstDate = Date(timeIntervalSince1970: 100)
        let secondDate = Date(timeIntervalSince1970: 200)
        let dto = ProductDTO.fixture(reviews: [
            ProductReviewDTO(rating: 2, comment: "First", date: firstDate, reviewerName: "A"),
            ProductReviewDTO(rating: 5, comment: "Second", date: secondDate, reviewerName: "B")
        ])

        let product = try ProductMapper().product(dto)

        #expect(product.reviews.map(\.id) == [1, 2])
        #expect(product.reviews.map(\.comment) == ["First", "Second"])
    }

    @Test
    func categoriesTrimDeduplicateFirstWinsAndSortBySlug() throws {
        let values = [
            ProductCategoryDTO(slug: " z ", name: " Zed ", url: URL(string: "https://dummyjson.com/z")!),
            ProductCategoryDTO(slug: "a", name: "First", url: URL(string: "https://dummyjson.com/a")!),
            ProductCategoryDTO(slug: "a", name: "Second", url: URL(string: "https://dummyjson.com/a2")!)
        ]

        let mapped = try ProductMapper().categories(values)

        #expect(mapped == [
            ProductCategory(slug: "a", name: "First"),
            ProductCategory(slug: "z", name: "Zed")
        ])
    }

    @Test(arguments: [
        ProductQuery(mode: .all, sort: nil, limit: 0, skip: 0),
        ProductQuery(mode: .all, sort: nil, limit: 101, skip: 0),
        ProductQuery(mode: .all, sort: nil, limit: 20, skip: -1),
        ProductQuery(mode: .search("  "), sort: nil, limit: 20, skip: 0),
        ProductQuery(mode: .category(""), sort: nil, limit: 20, skip: 0),
        ProductQuery(mode: .search("phone"), sort: .priceAscending, limit: 20, skip: 0),
        ProductQuery(mode: .category("phones"), sort: .titleDescending, limit: 20, skip: 0)
    ])
    func invalidQueriesFailBeforeTransport(query: ProductQuery) async {
        let remote = ProductRemoteSpy()
        let repository = ProductRepository(remote: remote)

        await #expect(throws: ProductRepositoryError.invalidQuery) {
            _ = try await repository.page(query)
        }
        #expect(await remote.requests.isEmpty)
    }

    @Test
    func allModeForwardsSupportedSortAndPaging() async throws {
        let remote = ProductRemoteSpy()
        let repository = ProductRepository(remote: remote)
        let query = ProductQuery(mode: .all, sort: .priceDescending, limit: 30, skip: 60)

        _ = try await repository.page(query)

        #expect(await remote.requests == [ProductPageRequest(mode: .all, sort: .priceDescending, limit: 30, skip: 60)])
    }

    @Test
    func relatedIsDeduplicatedSortedAndLimited() async throws {
        let remote = ProductRemoteSpy(pageIDs: [4, 2, 3, 4, 1])
        let repository = ProductRepository(remote: remote)

        let ids = try await repository.related(
            to: .fixture(id: 2, category: "phones"),
            limit: 3
        ).map(\.id)

        #expect(ids == [1, 3, 4])
    }
}

private actor ProductRemoteSpy: IRemoteService {
    let pageIDs: [Int]
    private(set) var requests: [ProductPageRequest] = []

    init(pageIDs: [Int] = []) { self.pageIDs = pageIDs }

    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO {
        requests.append(request)
        return ProductPageDTO(products: pageIDs.map { .fixture(id: $0) }, total: pageIDs.count, skip: request.skip, limit: request.limit)
    }
    func categories() async throws -> [ProductCategoryDTO] { [] }
    func product(id: Int) async throws -> ProductDTO { .fixture(id: id) }
    func login(_ request: LoginRequestDTO) async throws -> AuthSessionDTO { throw RemoteServiceError.invalidResponse }
    func me(accessToken: String) async throws -> UserProfileDTO { throw RemoteServiceError.invalidResponse }
    func refresh(_ request: RefreshRequestDTO) async throws -> AuthTokensDTO { throw RemoteServiceError.invalidResponse }
    func diagnostic(_ request: HTTPDiagnosticRequest) async throws -> HTTPDiagnosticDTO { throw RemoteServiceError.invalidResponse }
}
