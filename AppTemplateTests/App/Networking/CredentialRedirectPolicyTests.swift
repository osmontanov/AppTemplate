import Foundation
import Testing
@testable import AppTemplate

struct CredentialRedirectPolicyTests {
    @Test
    func prepareDisablesCookiesAndRemovesAmbientCredentialHeaders() throws {
        let body = Data("refresh-token".utf8)
        var request = URLRequest(url: try #require(URL(string: "https://auth.example.test/login")))
        request.httpShouldHandleCookies = true
        request.httpBody = body
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        request.setValue("session=ambient", forHTTPHeaderField: "Cookie")
        request.setValue("Basic proxy-secret", forHTTPHeaderField: "Proxy-Authorization")

        let prepared = CredentialRedirectPolicy().prepare(request)

        #expect(prepared.httpShouldHandleCookies == false)
        #expect(prepared.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(prepared.value(forHTTPHeaderField: "Proxy-Authorization") == nil)
        #expect(prepared.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(prepared.httpBody == body)
    }

    @Test
    func sameOriginRedirectNormalizesDefaultPortAndPreservesCredentialsAndBody() throws {
        let originalURL = try #require(URL(string: "https://AUTH.example.test/login"))
        let body = Data("refresh-token".utf8)
        var proposed = URLRequest(
            url: try #require(URL(string: "https://auth.example.test:443/refresh"))
        )
        proposed.httpBody = body
        proposed.setValue("Bearer secret", forHTTPHeaderField: "Authorization")

        let redirected = try #require(
            CredentialRedirectPolicy().redirectedRequest(
                proposed,
                from: originalURL
            )
        )

        #expect(redirected.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(redirected.httpBody == body)
        #expect(redirected.httpShouldHandleCookies == false)
    }

    @Test
    func crossOriginHostPortAndSchemeRedirectsAreRejected() throws {
        let policy = CredentialRedirectPolicy()
        let originalURL = try #require(URL(string: "https://auth.example.test/login"))
        let proposedURLs = try [
            #require(URL(string: "https://evil.example.test/steal")),
            #require(URL(string: "https://auth.example.test:444/steal")),
            #require(URL(string: "http://auth.example.test/steal"))
        ]

        for url in proposedURLs {
            #expect(
                policy.redirectedRequest(URLRequest(url: url), from: originalURL) == nil,
                "Unexpectedly allowed redirect to \(url.absoluteString)"
            )
        }
    }

    @Test
    func httpsDowngradeIsRejectedEvenWithExplicitDefaultPorts() throws {
        let originalURL = try #require(URL(string: "https://auth.example.test:443/login"))
        let proposed = URLRequest(
            url: try #require(URL(string: "http://auth.example.test:80/steal"))
        )

        #expect(
            CredentialRedirectPolicy().redirectedRequest(
                proposed,
                from: originalURL
            ) == nil
        )
    }

    @Test
    func missingOriginalURLIsRejected() throws {
        let proposed = URLRequest(
            url: try #require(URL(string: "https://auth.example.test/refresh"))
        )

        #expect(
            CredentialRedirectPolicy().redirectedRequest(
                proposed,
                from: nil
            ) == nil
        )
    }

    @Test
    func crossOrigin307NeverReplaysLoginBody() async throws {
        CredentialRedirectFixtureURLProtocol.reset()
        let transport = URLSessionTransport.cookieFree(
            timeout: 15,
            protocolClasses: [CredentialRedirectFixtureURLProtocol.self]
        )
        let body = Data("password=hunter2&refresh_token=secret".utf8)
        var request = URLRequest(
            url: try #require(URL(string: "https://auth.example.test/login"))
        )
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")

        let (_, response) = try await transport.data(for: request)
        let httpResponse = try #require(response as? HTTPURLResponse)

        #expect(httpResponse.statusCode == 307)
        #expect(CredentialRedirectFixtureURLProtocol.crossOriginRequests.isEmpty)
    }
}

nonisolated
final class CredentialRedirectFixtureURLProtocol: URLProtocol, @unchecked Sendable {
    private static let recorder = CredentialRedirectFixtureRecorder()

    static var crossOriginRequests: [URLRequest] {
        recorder.requests
    }

    static func reset() {
        recorder.reset()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasSuffix("example.test") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        if url.host == "evil.example.test" {
            Self.recorder.record(request)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let destination = URL(string: "https://evil.example.test/collect")!
        var redirected = URLRequest(url: destination)
        redirected.httpMethod = request.httpMethod
        redirected.httpBody = request.httpBody
        redirected.allHTTPHeaderFields = request.allHTTPHeaderFields
        let response = HTTPURLResponse(
            url: url,
            statusCode: 307,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": destination.absoluteString]
        )!
        client?.urlProtocol(
            self,
            wasRedirectedTo: redirected,
            redirectResponse: response
        )
        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

nonisolated
private final class CredentialRedirectFixtureRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedRequests: [URLRequest] = []

    var requests: [URLRequest] {
        lock.withLock { recordedRequests }
    }

    func record(_ request: URLRequest) {
        lock.withLock {
            recordedRequests.append(request)
        }
    }

    func reset() {
        lock.withLock {
            recordedRequests = []
        }
    }
}
