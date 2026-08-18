import Foundation

// A URLProtocol whose script is keyed by URL, so a test states the exact wire
// behaviour it wants — including a body delivered in chunks, which is the only
// way to observe a mid-stream abort.
nonisolated
final class ImageURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated struct Script: Sendable {
        var statusCode = 200
        var headers: [String: String] = ["Content-Type": "image/png"]
        var chunks: [Data] = []
        var redirectTo: URL?
        var failure: URLError?
        var stallsForever = false
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var scripts: [URL: Script] = [:]
    nonisolated(unsafe) private static var deliveredChunks: [URL: Int] = [:]

    private let stopped = NSLock()
    nonisolated(unsafe) private var isStopped = false

    static func set(_ script: Script, for url: URL) {
        lock.withLock {
            scripts[url] = script
            deliveredChunks[url] = 0
        }
    }

    static func reset() {
        lock.withLock {
            scripts.removeAll()
            deliveredChunks.removeAll()
        }
    }

    static func chunksDelivered(for url: URL) -> Int {
        lock.withLock { deliveredChunks[url] ?? 0 }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return lock.withLock { scripts[url] != nil }
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let script = Self.lock.withLock({ Self.scripts[url] })
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        if script.stallsForever { return }
        if let failure = script.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        if let redirectTo = script.redirectTo {
            let response = HTTPURLResponse(
                url: url,
                statusCode: 302,
                httpVersion: "HTTP/1.1",
                headerFields: ["Location": redirectTo.absoluteString]
            )!
            var followUp = URLRequest(url: redirectTo)
            followUp.httpMethod = request.httpMethod
            client?.urlProtocol(self, wasRedirectedTo: followUp, redirectResponse: response)
            return
        }

        var headers = script.headers
        if headers["Content-Length"] == nil {
            let declared = script.chunks.reduce(0) { $0 + $1.count }
            headers["Content-Length"] = String(declared)
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: script.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for chunk in script.chunks {
            guard !stopped.withLock({ isStopped }) else { return }
            Self.lock.withLock { Self.deliveredChunks[url, default: 0] += 1 }
            client?.urlProtocol(self, didLoad: chunk)
            // The delegate cancels from URLSession's queue; yielding here is what
            // lets that cancellation land between chunks instead of after them.
            Thread.sleep(forTimeInterval: 0.002)
        }
        guard !stopped.withLock({ isStopped }) else { return }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        stopped.withLock { isStopped = true }
    }
}

nonisolated
enum ImageFixtures {
    // 1x1 PNG.
    static let png = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )!

    static let jpegHeader = Data([0xFF, 0xD8, 0xFF])
    static let gifHeader = Data("GIF89a".utf8)
    static let webpHeader = Data("RIFF".utf8) + Data([0, 0, 0, 0]) + Data("WEBP".utf8)

    static let allowedURL = URL(string: "https://cdn.dummyjson.com/product.png")!
    static let otherAllowedURL = URL(string: "https://dummyjson.com/image/other.png")!
    static let foreignURL = URL(string: "https://evil.example.com/product.png")!
}
