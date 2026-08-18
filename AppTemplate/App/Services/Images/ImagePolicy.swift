import Foundation

nonisolated
struct ImagePolicy: Hashable, Sendable {
    let allowedHosts: Set<String>
    let timeout: Duration
    let maximumEncodedBytes: Int
    let maximumPixelSide: Int

    static let product = ImagePolicy(
        allowedHosts: [
            RemoteOrigin.dummyJSON.host,
            "cdn." + RemoteOrigin.dummyJSON.host
        ],
        timeout: .seconds(15),
        maximumEncodedBytes: 5 * 1_024 * 1_024,
        maximumPixelSide: 4_096
    )

    func permits(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              allowedHosts.contains(where: { $0.lowercased() == host }),
              url.port == nil || url.port == 443,
              url.user == nil,
              url.password == nil,
              url.fragment == nil
        else {
            return false
        }
        return true
    }

    var timeoutInterval: TimeInterval {
        let components = timeout.components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        return max(0.001, seconds + attoseconds)
    }
}
