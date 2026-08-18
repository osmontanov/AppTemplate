import Foundation

// The one place a backend host is named. RemoteService refuses any base URL that
// does not match the origin it was built with, so swapping backends means passing
// a different origin here — not editing a literal buried in request validation.
nonisolated
struct RemoteOrigin: Equatable, Sendable {
    static let dummyJSON = RemoteOrigin(
        scheme: "https",
        host: "dummyjson.com",
        port: 443
    )

    let scheme: String
    let host: String
    let port: Int

    var baseURL: URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        if port != defaultPort(for: scheme) {
            components.port = port
        }
        return components.url
    }

    func permits(_ url: URL) -> Bool {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == scheme.lowercased(),
            components.host?.lowercased() == host.lowercased(),
            (components.port ?? defaultPort(for: scheme)) == port,
            components.user == nil,
            components.password == nil,
            components.query == nil,
            components.fragment == nil,
            components.path.isEmpty || components.path == "/"
        else { return false }
        return true
    }

    private func defaultPort(for scheme: String) -> Int {
        scheme.lowercased() == "http" ? 80 : 443
    }
}
