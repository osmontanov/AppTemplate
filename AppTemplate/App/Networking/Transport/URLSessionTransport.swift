import Foundation

nonisolated
struct URLSessionTransport: NetworkTransport {
    private let session: URLSession
    private let retainedRedirectDelegate: CredentialRedirectDelegate?
    private let prepareRequest: @Sendable (URLRequest) -> URLRequest

    init(session: URLSession = .shared) {
        self.session = session
        retainedRedirectDelegate = nil
        prepareRequest = { $0 }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: prepareRequest(request), delegate: nil)
    }

    static func cookieFree(
        timeout: TimeInterval = 15
    ) -> URLSessionTransport {
        cookieFree(timeout: timeout, protocolClasses: nil)
    }

    static func ephemeral(
        timeout: TimeInterval = 15
    ) -> URLSessionTransport {
        URLSessionTransport(
            configuration: EphemeralURLSessionConfiguration.make(
                timeout: timeout
            ),
            redirectDelegate: nil,
            prepareRequest: { $0 }
        )
    }

    static func cookieFree(
        timeout: TimeInterval,
        protocolClasses: [AnyClass]?
    ) -> URLSessionTransport {
        let policy = CredentialRedirectPolicy()
        let delegate = CredentialRedirectDelegate(policy: policy)
        return URLSessionTransport(
            configuration: CookieFreeURLSessionConfiguration.make(
                timeout: timeout,
                protocolClasses: protocolClasses
            ),
            redirectDelegate: delegate,
            prepareRequest: policy.prepare
        )
    }

    private init(
        configuration: URLSessionConfiguration,
        redirectDelegate: CredentialRedirectDelegate?,
        prepareRequest: @escaping @Sendable (URLRequest) -> URLRequest
    ) {
        session = URLSession(
            configuration: configuration,
            delegate: redirectDelegate,
            delegateQueue: nil
        )
        retainedRedirectDelegate = redirectDelegate
        self.prepareRequest = prepareRequest
    }
}

nonisolated
private final class CredentialRedirectDelegate: NSObject,
    URLSessionTaskDelegate,
    @unchecked Sendable
{
    private let policy: CredentialRedirectPolicy

    init(policy: CredentialRedirectPolicy) {
        self.policy = policy
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(
            policy.redirectedRequest(request, from: response.url)
        )
    }
}
