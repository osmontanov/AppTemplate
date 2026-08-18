import Foundation
import Testing
@testable import AppTemplate

struct ImagePolicyTests {
    @Test(arguments: [
        "https://dummyjson.com/image/a.png",
        "https://cdn.dummyjson.com/a.png",
        "https://CDN.DummyJSON.com/a.png",
        "https://cdn.dummyjson.com:443/a.png"
    ])
    func permitsAllowlistedHTTPSOrigins(_ raw: String) throws {
        let url = try #require(URL(string: raw))
        #expect(ImagePolicy.product.permits(url))
    }

    @Test(arguments: [
        "http://cdn.dummyjson.com/a.png",
        "https://evil.example.com/a.png",
        "https://cdn.dummyjson.com.evil.example.com/a.png",
        "https://cdn.dummyjson.com:8443/a.png",
        "https://user:pass@cdn.dummyjson.com/a.png",
        "https://cdn.dummyjson.com/a.png#fragment",
        "file:///tmp/a.png",
        "data:image/png;base64,AAAA"
    ])
    func rejectsEverythingOutsideTheAllowlist(_ raw: String) throws {
        let url = try #require(URL(string: raw))
        #expect(!ImagePolicy.product.permits(url))
    }

    @Test
    func productPolicyNamesTheBackendThroughRemoteOriginOnly() {
        #expect(ImagePolicy.product.allowedHosts == [
            RemoteOrigin.dummyJSON.host,
            "cdn." + RemoteOrigin.dummyJSON.host
        ])
    }

    @Test
    func timeoutIntervalNeverCollapsesToZero() {
        let policy = ImagePolicy(
            allowedHosts: [],
            timeout: .zero,
            maximumEncodedBytes: 1,
            maximumPixelSide: 1
        )
        #expect(policy.timeoutInterval == 0.001)
        #expect(ImagePolicy.product.timeoutInterval == 15)
    }
}
