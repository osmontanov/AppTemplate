import Foundation
import Testing
@testable import AppTemplate

struct DummyJSONTargetTests {
    private let baseURL = URL(string: "https://dummyjson.com")!

    @Test
    func productTargetsBuildDocumentedPathsQueriesAndSortMapping() throws {
        let cases: [(ProductPageRequest, String, [String: String])] = [
            (
                ProductPageRequest(mode: .all, sort: nil, limit: 20, skip: 40),
                "/products",
                ["limit": "20", "skip": "40"]
            ),
            (
                ProductPageRequest(
                    mode: .all,
                    sort: .titleAscending,
                    limit: 20,
                    skip: 0
                ),
                "/products",
                [
                    "limit": "20", "skip": "0", "sortBy": "title",
                    "order": "asc"
                ]
            ),
            (
                ProductPageRequest(
                    mode: .search("phone & tablet"),
                    sort: .titleDescending,
                    limit: 10,
                    skip: 5
                ),
                "/products/search",
                [
                    "q": "phone & tablet", "limit": "10", "skip": "5",
                    "sortBy": "title", "order": "desc"
                ]
            ),
            (
                ProductPageRequest(
                    mode: .category("smartphones/featured"),
                    sort: .priceAscending,
                    limit: 8,
                    skip: 0
                ),
                "/products/category/smartphones/featured",
                [
                    "limit": "8", "skip": "0", "sortBy": "price",
                    "order": "asc"
                ]
            ),
            (
                ProductPageRequest(
                    mode: .all,
                    sort: .priceDescending,
                    limit: 5,
                    skip: 10
                ),
                "/products",
                [
                    "limit": "5", "skip": "10", "sortBy": "price",
                    "order": "desc"
                ]
            )
        ]

        for (page, expectedPath, expectedQuery) in cases {
            let target = DummyJSONTarget.products(baseURL: baseURL, page)
            let request = try NetworkRequestBuilder().build(target)
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == expectedPath)
            #expect(query(request) == expectedQuery)
            #expect(target.shouldHandleCookies)
            #expect(target.sampleResponse.statusCode == 200)
        }
    }

    @Test
    func categoryDetailAndAuthenticationTargetsUseObjectAndCookieFreeContracts() throws {
        let login = LoginRequestDTO(
            username: "emilys",
            password: "secret",
            expiresInMins: 30
        )
        let refresh = RefreshRequestDTO(
            refreshToken: "refresh-secret",
            expiresInMins: 30
        )
        let cases: [(DummyJSONTarget, String, String, Bool)] = [
            (.categories(baseURL: baseURL), "/products/categories", "GET", true),
            (.product(baseURL: baseURL, id: 7), "/products/7", "GET", true),
            (.login(baseURL: baseURL, login), "/auth/login", "POST", false),
            (.me(baseURL: baseURL, accessToken: "token"), "/auth/me", "GET", false),
            (.refresh(baseURL: baseURL, refresh), "/auth/refresh", "POST", false)
        ]

        for (target, path, method, handlesCookies) in cases {
            let request = try NetworkRequestBuilder().build(target)
            #expect(request.url?.path == path)
            #expect(request.httpMethod == method)
            #expect(target.shouldHandleCookies == handlesCookies)
            #expect(target.sampleResponse.statusCode == 200)
        }

        let categoryData = DummyJSONTarget.categories(baseURL: baseURL)
            .sampleResponse.data
        let categories = try JSONDecoder().decode(
            [ProductCategoryDTO].self,
            from: categoryData
        )
        #expect(categories.first?.slug == "beauty")

        let meRequest = try NetworkRequestBuilder().build(
            DummyJSONTarget.me(baseURL: baseURL, accessToken: "token")
        )
        #expect(meRequest.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(meRequest.httpShouldHandleCookies == false)
    }

    @Test
    func diagnosticTargetsUseDocumentedDelayAndStatusRoutes() throws {
        let delay = DummyJSONTarget.diagnostic(
            baseURL: baseURL,
            .delay(milliseconds: 5000)
        )
        let status = DummyJSONTarget.diagnostic(
            baseURL: baseURL,
            .status(code: 503)
        )
        let delayRequest = try NetworkRequestBuilder().build(delay)
        let statusRequest = try NetworkRequestBuilder().build(status)

        #expect(delayRequest.url?.path == "/products")
        #expect(query(delayRequest) == ["delay": "5000"])
        #expect(statusRequest.url?.path == "/http/503")
        #expect(delay.diagnosticDescriptor?.safePath == "/products")
        #expect(status.diagnosticDescriptor?.safePath == "/http/<status>")
    }

    @Test
    func descriptorsContainOnlyAllowlistedNamesAndPlaceholders() {
        let searchSecret = "search-secret"
        let categorySecret = "category-secret"
        let tokenSecret = "token-secret"
        let passwordSecret = "password-secret"
        let targets: [DummyJSONTarget] = [
            .products(
                baseURL: baseURL,
                ProductPageRequest(
                    mode: .search(searchSecret),
                    sort: nil,
                    limit: 10,
                    skip: 0
                )
            ),
            .products(
                baseURL: baseURL,
                ProductPageRequest(
                    mode: .category(categorySecret),
                    sort: nil,
                    limit: 10,
                    skip: 0
                )
            ),
            .login(
                baseURL: baseURL,
                LoginRequestDTO(
                    username: "user-secret",
                    password: passwordSecret,
                    expiresInMins: 30
                )
            ),
            .me(baseURL: baseURL, accessToken: tokenSecret)
        ]

        let rendered = String(reflecting: targets.compactMap(\.diagnosticDescriptor))
        for secret in [searchSecret, categorySecret, tokenSecret, passwordSecret, "user-secret"] {
            #expect(rendered.contains(secret) == false)
        }
        #expect(rendered.contains("/products/category/<slug>"))
    }

    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: (URLComponents(
                url: request.url!,
                resolvingAgainstBaseURL: false
            )?.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
    }
}
