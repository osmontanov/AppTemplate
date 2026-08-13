import Foundation

nonisolated
struct CredentialRedirectPolicy: Sendable {
    func prepare(_ request: URLRequest) -> URLRequest {
        var request = request
        request.httpShouldHandleCookies = false
        request.setValue(nil, forHTTPHeaderField: "Cookie")
        request.setValue(nil, forHTTPHeaderField: "Proxy-Authorization")
        return request
    }

    func redirectedRequest(
        _ proposed: URLRequest,
        from originalURL: URL?
    ) -> URLRequest? {
        guard
            let originalOrigin = origin(for: originalURL),
            let proposedOrigin = origin(for: proposed.url),
            originalOrigin == proposedOrigin
        else {
            return nil
        }

        return prepare(proposed)
    }

    private func origin(for url: URL?) -> Origin? {
        guard
            let url,
            let scheme = url.scheme?.lowercased(),
            let host = url.host?.lowercased(),
            !host.isEmpty,
            let port = effectivePort(for: url, scheme: scheme)
        else {
            return nil
        }

        return Origin(scheme: scheme, host: host, port: port)
    }

    private func effectivePort(for url: URL, scheme: String) -> Int? {
        if let port = url.port {
            return port
        }
        switch scheme {
        case "http":
            return 80
        case "https":
            return 443
        default:
            return nil
        }
    }
}

nonisolated
private struct Origin: Equatable, Sendable {
    let scheme: String
    let host: String
    let port: Int
}
