import Foundation

nonisolated
enum DummyJSONTarget: NetworkTarget {
    case products(baseURL: URL, ProductPageRequest)
    case categories(baseURL: URL)
    case product(baseURL: URL, id: Int)
    case login(baseURL: URL, LoginRequestDTO)
    case me(baseURL: URL, accessToken: String)
    case refresh(baseURL: URL, RefreshRequestDTO)
    case diagnostic(baseURL: URL, HTTPDiagnosticRequest)

    var baseURL: URL {
        switch self {
        case let .products(baseURL, _),
             let .categories(baseURL),
             let .product(baseURL, _),
             let .login(baseURL, _),
             let .me(baseURL, _),
             let .refresh(baseURL, _),
             let .diagnostic(baseURL, _):
            baseURL
        }
    }

    var path: String {
        switch self {
        case let .products(_, request):
            switch request.mode {
            case .all: "/products"
            case .search: "/products/search"
            case let .category(slug): "/products/category/\(slug)"
            }
        case .categories: "/products/categories"
        case let .product(_, id): "/products/\(id)"
        case .login: "/auth/login"
        case .me: "/auth/me"
        case .refresh: "/auth/refresh"
        case let .diagnostic(_, request):
            switch request {
            case .delay: "/products"
            case let .status(code): "/http/\(code)"
            }
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login, .refresh: .post
        default: .get
        }
    }

    var task: NetworkTask {
        switch self {
        case let .products(_, request):
            var queryItems: [URLQueryItem] = []
            if case let .search(query) = request.mode {
                queryItems.append(URLQueryItem(name: "q", value: query))
            }
            queryItems.append(contentsOf: [
                URLQueryItem(name: "limit", value: String(request.limit)),
                URLQueryItem(name: "skip", value: String(request.skip))
            ])
            if let sort = request.sort {
                let values = sort.queryValues
                queryItems.append(contentsOf: [
                    URLQueryItem(name: "sortBy", value: values.field),
                    URLQueryItem(name: "order", value: values.order)
                ])
            }
            return .query(queryItems)

        case let .login(_, request):
            return .json(request)
        case let .refresh(_, request):
            return .json(request)
        case let .diagnostic(_, .delay(milliseconds)):
            return .query([
                URLQueryItem(name: "delay", value: String(milliseconds))
            ])
        default:
            return .plain
        }
    }

    var headers: HTTPHeaders {
        switch self {
        case let .me(_, accessToken):
            ["Authorization": "Bearer \(accessToken)"]
        default:
            [:]
        }
    }

    var shouldHandleCookies: Bool {
        switch self {
        case .login, .me, .refresh: false
        default: true
        }
    }

    var sampleResponse: StubResponse {
        switch self {
        case .products, .diagnostic(_, .delay):
            Self.jsonSample(
                #"{"products":[],"total":0,"skip":0,"limit":0}"#
            )
        case .categories:
            Self.jsonSample(
                #"[{"slug":"beauty","name":"Beauty","url":"https://dummyjson.com/products/category/beauty"}]"#
            )
        case .product:
            Self.jsonSample(Self.productSample)
        case .login:
            Self.jsonSample(
                #"{"id":1,"username":"emilys","firstName":"Emily","lastName":"Johnson","email":"emily@example.com","image":"https://dummyjson.com/icon/emilys/128","accessToken":"sample-access","refreshToken":"sample-refresh"}"#
            )
        case .me:
            Self.jsonSample(
                #"{"id":1,"username":"emilys","firstName":"Emily","lastName":"Johnson","email":"emily@example.com","image":"https://dummyjson.com/icon/emilys/128"}"#
            )
        case .refresh:
            Self.jsonSample(
                #"{"accessToken":"sample-access","refreshToken":"sample-refresh"}"#
            )
        case let .diagnostic(_, .status(code)):
            StubResponse(statusCode: code)
        }
    }

    var diagnosticDescriptor: NetworkDiagnosticDescriptor? {
        switch self {
        case let .products(_, request):
            switch request.mode {
            case .all:
                descriptor("products", "/products", productQueryKeys(request))
            case .search:
                descriptor(
                    "product-search",
                    "/products/search",
                    ["q"] + productQueryKeys(request)
                )
            case .category:
                descriptor(
                    "product-category",
                    "/products/category/<slug>",
                    productQueryKeys(request)
                )
            }
        case .categories:
            descriptor("product-categories", "/products/categories")
        case .product:
            descriptor("product-detail", "/products/<id>")
        case .login:
            descriptor("auth-login", "/auth/login")
        case .me:
            descriptor("auth-profile", "/auth/me")
        case .refresh:
            descriptor("auth-refresh", "/auth/refresh")
        case .diagnostic(_, .delay):
            descriptor("http-delay", "/products", ["delay"])
        case .diagnostic(_, .status):
            descriptor("http-status", "/http/<status>")
        }
    }

    private func productQueryKeys(_ request: ProductPageRequest) -> [String] {
        var keys = ["limit", "skip"]
        if request.sort != nil {
            keys.append(contentsOf: ["sortBy", "order"])
        }
        return keys
    }

    private func descriptor(
        _ operation: String,
        _ safePath: String,
        _ queryKeys: [String] = []
    ) -> NetworkDiagnosticDescriptor {
        NetworkDiagnosticDescriptor(
            operation: operation,
            safePath: safePath,
            queryKeys: queryKeys
        )
    }

    private static func jsonSample(_ json: String) -> StubResponse {
        StubResponse(
            statusCode: 200,
            data: Data(json.utf8),
            headers: ["Content-Type": "application/json"]
        )
    }

    private static let productSample =
        #"{"id":1,"title":"Sample product","description":"Sample","category":"beauty","price":9.99,"rating":4.5,"stock":1,"brand":"Sample","availabilityStatus":"In Stock","reviews":[],"images":[],"thumbnail":null}"#
}

nonisolated
private extension ProductSort {
    var queryValues: (field: String, order: String) {
        switch self {
        case .titleAscending: ("title", "asc")
        case .titleDescending: ("title", "desc")
        case .priceAscending: ("price", "asc")
        case .priceDescending: ("price", "desc")
        }
    }
}
