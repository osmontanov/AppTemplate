import Foundation
import Testing
@testable import AppTemplate

struct DummyJSONRemoteServiceTests {
    @Test
    func productOperationsDecodeISO8601ReviewsAndAnnotateOneOperationID() async throws {
        let recorder = NetworkDiagnosticRecorder()
        let publicTransport = InMemoryNetworkTransport { request in
            let data: Data
            switch request.url?.path {
            case "/products":
                data = Self.pageJSON
            case "/products/categories":
                data = Self.categoriesJSON
            case "/products/1":
                data = Self.productJSON
            default:
                throw DummyServiceFixtureError.unexpectedRequest
            }
            return (data, Self.response(request, status: 200))
        }
        let authTransport = unexpectedDummyTransport()
        let service = makeService(
            publicTransport: publicTransport,
            authTransport: authTransport,
            recorder: recorder
        )

        let page = try await service.products(
            ProductPageRequest(mode: .all, sort: nil, limit: 1, skip: 0)
        )
        let categories = try await service.categories()
        let product = try await service.product(id: 1)
        let events = await recorder.events()

        #expect(page.products[0].reviews[0].date == Self.reviewDate)
        #expect(categories[0].name == "Beauty")
        #expect(product.id == 1)
        #expect(events.count == 3)
        #expect(events[0].summary == .productPage(count: 1, total: 194))
        #expect(events[1].summary == .categories(count: 1))
        #expect(events[2].summary == .product(id: 1))
        #expect(Set(events.map(\.operationID)).count == 3)
        #expect(await authTransport.recordedRequests().isEmpty)
    }

    @Test
    func authenticationUsesOnlyCookieFreeProviderAndNormalizesExpiry() async throws {
        let recorder = NetworkDiagnosticRecorder()
        let publicTransport = unexpectedDummyTransport()
        let authTransport = InMemoryNetworkTransport { request in
            let data: Data
            switch request.url?.path {
            case "/auth/login": data = Self.sessionJSON
            case "/auth/me": data = Self.profileJSON
            case "/auth/refresh": data = Self.tokensJSON
            default: throw DummyServiceFixtureError.unexpectedRequest
            }
            return (data, Self.response(request, status: 200))
        }
        let service = makeService(
            publicTransport: publicTransport,
            authTransport: authTransport,
            recorder: recorder
        )

        _ = try await service.login(
            LoginRequestDTO(username: "emilys", password: "secret", expiresInMins: 1)
        )
        _ = try await service.me(accessToken: "access-secret")
        _ = try await service.refresh(
            RefreshRequestDTO(refreshToken: "refresh-secret", expiresInMins: 1)
        )

        let requests = await authTransport.recordedRequests()
        #expect(requests.map { $0.url?.path } == ["/auth/login", "/auth/me", "/auth/refresh"])
        #expect(requests.allSatisfy { $0.httpShouldHandleCookies == false })
        #expect(requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer access-secret")
        let loginBody = try #require(requests[0].httpBody)
        let refreshBody = try #require(requests[2].httpBody)
        #expect(try JSONDecoder().decode(LoginRequestDTO.self, from: loginBody).expiresInMins == 30)
        #expect(try JSONDecoder().decode(RefreshRequestDTO.self, from: refreshBody).expiresInMins == 30)
        #expect(await publicTransport.recordedRequests().isEmpty)
        #expect(await recorder.events().map(\.summary) == [
            .profile(id: 1), .profile(id: 1), .tokenRefresh
        ])
    }

    @Test
    func authenticationStatusDecodesOnlyTheIntentionalSafeErrorDTO() async {
        let authTransport = InMemoryNetworkTransport { request in
            (
                Data(#"{"message":"Invalid credentials"}"#.utf8),
                Self.response(request, status: 401)
            )
        }
        let service = makeService(
            publicTransport: unexpectedDummyTransport(),
            authTransport: authTransport,
            recorder: NetworkDiagnosticRecorder()
        )

        await expectRemoteError(
            .status(
                code: 401,
                authenticationError: AuthErrorDTO(
                    message: "Invalid credentials"
                )
            )
        ) {
            try await service.login(
                LoginRequestDTO(
                    username: "emilys",
                    password: "wrong",
                    expiresInMins: 30
                )
            )
        }
    }

    @Test
    func delayAndStatusValidateDocumentedBoundsBeforeTransport() async throws {
        let recorder = NetworkDiagnosticRecorder()
        let transport = InMemoryNetworkTransport { request in
            if request.url?.path == "/products" {
                return (Self.pageJSON, Self.response(request, status: 200))
            }
            return (
                Data("status error bytes".utf8),
                Self.response(request, status: 418)
            )
        }
        let service = makeService(
            publicTransport: transport,
            authTransport: unexpectedDummyTransport(),
            recorder: recorder
        )

        #expect(try await service.diagnostic(.delay(milliseconds: 0)).statusCode == 200)
        #expect(try await service.diagnostic(.delay(milliseconds: 5000)).statusCode == 200)
        await expectRemoteError(.invalidResponse) {
            try await service.diagnostic(.delay(milliseconds: -1))
        }
        await expectRemoteError(.invalidResponse) {
            try await service.diagnostic(.delay(milliseconds: 5001))
        }
        await expectRemoteError(.invalidResponse) {
            try await service.diagnostic(.status(code: 99))
        }
        await expectRemoteError(.invalidResponse) {
            try await service.diagnostic(.status(code: 600))
        }
        await expectRemoteError(.status(code: 418, authenticationError: nil)) {
            try await service.diagnostic(.status(code: 418))
        }

        let requests = await transport.recordedRequests()
        #expect(requests.count == 3)
        #expect(requests[0].url?.query == "delay=0")
        #expect(requests[1].url?.query == "delay=5000")
        #expect(requests[2].url?.path == "/http/418")
    }

    @Test
    func untrustedInitialOriginsFailBeforeAnyCredentialOrPublicTransportCall() async {
        let invalidOrigins = [
            "http://dummyjson.com", "https://dummyjson.com.evil.test",
            "https://127.0.0.1", "https://dummyjson.com:444",
            "https://user:pass@dummyjson.com", "https://dummyjson.com?x=1",
            "https://dummyjson.com#fragment", "https://dummyjson.com/v1"
        ]

        for rawOrigin in invalidOrigins {
            let publicTransport = unexpectedDummyTransport()
            let authTransport = unexpectedDummyTransport()
            let service = makeService(
                baseURL: URL(string: rawOrigin)!,
                publicTransport: publicTransport,
                authTransport: authTransport,
                recorder: NetworkDiagnosticRecorder()
            )

            await expectRemoteError(.invalidResponse) {
                try await service.login(
                    LoginRequestDTO(
                        username: "user",
                        password: "password-secret",
                        expiresInMins: 30
                    )
                )
            }
            await expectRemoteError(.invalidResponse) {
                try await service.products(
                    ProductPageRequest(mode: .all, sort: nil, limit: 1, skip: 0)
                )
            }
            #expect(await publicTransport.recordedRequests().isEmpty)
            #expect(await authTransport.recordedRequests().isEmpty)
        }
    }

    @Test
    func trustedOriginAllowsCaseNormalizationExplicit443AndRootSlash() async throws {
        for rawOrigin in [
            "https://dummyjson.com", "https://DUMMYJSON.COM:443/"
        ] {
            let transport = InMemoryNetworkTransport { request in
                (Self.categoriesJSON, Self.response(request, status: 200))
            }
            let service = makeService(
                baseURL: URL(string: rawOrigin)!,
                publicTransport: transport,
                authTransport: unexpectedDummyTransport(),
                recorder: NetworkDiagnosticRecorder()
            )
            #expect(try await service.categories().count == 1)
            #expect(await transport.recordedRequests().count == 1)
        }
    }

    @Test
    func networkAndDecodingFailuresMapToClosedSafeErrors() async {
        let recorder = NetworkDiagnosticRecorder()
        let transportFailure = makeService(
            publicTransport: InMemoryNetworkTransport { _ in
                throw SecretTransportError(value: "transport-secret")
            },
            authTransport: unexpectedDummyTransport(),
            recorder: recorder
        )
        await expectRemoteError(.transport) {
            try await transportFailure.categories()
        }

        let invalidResponse = makeService(
            publicTransport: InMemoryNetworkTransport { request in
                (Data("invalid-secret".utf8), Self.response(request, status: 200))
            },
            authTransport: unexpectedDummyTransport(),
            recorder: recorder
        )
        await expectRemoteError(.invalidResponse) {
            try await invalidResponse.categories()
        }

        let rendered = String(reflecting: await recorder.events())
            + String(reflecting: RemoteServiceError.transport)
        #expect(rendered.contains("transport-secret") == false)
        #expect(rendered.contains("invalid-secret") == false)
    }

    private func makeService(
        baseURL: URL = URL(string: "https://dummyjson.com")!,
        publicTransport: InMemoryNetworkTransport,
        authTransport: InMemoryNetworkTransport,
        recorder: NetworkDiagnosticRecorder
    ) -> RemoteService {
        RemoteService(
            dummyJSONBaseURL: baseURL,
            dummyJSONProvider: NetworkProvider(
                transport: publicTransport,
                diagnosticRecorder: recorder
            ),
            authenticationProvider: NetworkProvider(
                transport: authTransport,
                diagnosticRecorder: recorder
            ),
            diagnosticRecorder: recorder
        )
    }

    nonisolated private static func response(
        _ request: URLRequest,
        status: Int
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private static let reviewDate = Date(timeIntervalSince1970: 1_716_454_581)
    nonisolated private static let productJSON = Data(#"""
    {
        "id":1,"title":"Essence Mascara Lash Princess","description":"Mascara",
        "category":"beauty","price":9.99,"rating":4.94,"stock":5,
        "brand":"Essence","availabilityStatus":"Low Stock",
        "reviews":[{"rating":2,"comment":"Very unhappy","date":"2024-05-23T08:56:21Z","reviewerName":"John Doe"}],
        "images":["https://example.test/product.png"],
        "thumbnail":"https://example.test/thumb.png"
    }
    """#.utf8)
    nonisolated private static let pageJSON = Data(#"""
    {
        "products":[{
            "id":1,"title":"Essence Mascara Lash Princess","description":"Mascara",
            "category":"beauty","price":9.99,"rating":4.94,"stock":5,
            "brand":"Essence","availabilityStatus":"Low Stock",
            "reviews":[{"rating":2,"comment":"Very unhappy","date":"2024-05-23T08:56:21Z","reviewerName":"John Doe"}],
            "images":["https://example.test/product.png"],
            "thumbnail":"https://example.test/thumb.png"
        }],"total":194,"skip":0,"limit":1
    }
    """#.utf8)
    nonisolated private static let categoriesJSON = Data(#"""
    [
        {"slug":"beauty","name":"Beauty","url":"https://dummyjson.com/products/category/beauty"}
    ]
    """#.utf8)
    nonisolated private static let sessionJSON = Data(#"""
    {
        "id":1,"username":"emilys","firstName":"Emily","lastName":"Johnson",
        "email":"emily@example.test","image":"https://example.test/emily.png",
        "accessToken":"access","refreshToken":"refresh"
    }
    """#.utf8)
    nonisolated private static let profileJSON = Data(#"""
    {
        "id":1,"username":"emilys","firstName":"Emily","lastName":"Johnson",
        "email":"emily@example.test","image":"https://example.test/emily.png"
    }
    """#.utf8)
    nonisolated private static let tokensJSON = Data(#"""
    {
        "accessToken":"access-2","refreshToken":"refresh-2"
    }
    """#.utf8)
}

private func expectRemoteError<Value: Sendable>(
    _ expected: RemoteServiceError,
    operation: () async throws -> Value
) async {
    do {
        _ = try await operation()
        Issue.record("Expected RemoteServiceError \(expected)")
    } catch let error as RemoteServiceError {
        #expect(error == expected)
    } catch {
        Issue.record("Unexpected error type: \(type(of: error))")
    }
}

private func unexpectedDummyTransport() -> InMemoryNetworkTransport {
    InMemoryNetworkTransport { _ in
        throw DummyServiceFixtureError.unexpectedRequest
    }
}

nonisolated
private enum DummyServiceFixtureError: Error {
    case unexpectedRequest
}

nonisolated
private struct SecretTransportError: Error {
    let value: String
}
