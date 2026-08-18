import Foundation
import Testing
@testable import AppTemplate

struct ProductImageLoaderTests {
    @Test
    func rejectsOriginBeforeTransport() async {
        let transport = ImageTransportSpy(response: .png)

        await #expect(throws: ImageLoaderError.disallowedOrigin) {
            try await ProductImageLoader(transport: transport).load(
                URL(string: "https://evil.example/x.png")!,
                policy: .product
            )
        }
        #expect(await transport.callCount == 0)
    }

    @Test(
        arguments: [
            "http://dummyjson.com/x.png",
            "https://user@dummyjson.com/x.png",
            "https://dummyjson.com:444/x.png",
            "https://dummyjson.com/x.png#fragment",
            "https://dummyjson.com.evil.example/x.png"
        ]
    )
    func rejectsUnsafeInitialURLs(_ value: String) async {
        let transport = ImageTransportSpy(response: .png)

        await #expect(throws: ImageLoaderError.disallowedOrigin) {
            try await ProductImageLoader(transport: transport).load(
                URL(string: value)!,
                policy: .product
            )
        }
        #expect(await transport.callCount == 0)
    }

    @Test
    func acceptsDefaultHTTPSPortAndNormalizesMIMEParameters() async throws {
        let response = ImageHTTPResponse(
            finalURL: URL(string: "https://dummyjson.com:443/image")!,
            statusCode: 200,
            mimeType: " Image/PNG ; charset=binary ",
            data: ImageFixture.png
        )

        let image = try await ProductImageLoader(
            transport: ImageTransportSpy(response: response)
        ).load(
            URL(string: "https://dummyjson.com:443/image")!,
            policy: .product
        )

        #expect(image.mimeType == "image/png")
        #expect(image.pixelWidth == 1)
        #expect(image.pixelHeight == 1)
        #expect(image.data == ImageFixture.png)
    }

    @Test(arguments: ImageFixture.validCases)
    func validatesSupportedImageSignaturesAndDimensions(_ fixture: ImageFixture.Case) async throws {
        let response = ImageHTTPResponse(
            finalURL: URL(string: "https://cdn.dummyjson.com/image")!,
            statusCode: 200,
            mimeType: fixture.mimeType,
            data: fixture.data
        )

        let image = try await ProductImageLoader(
            transport: ImageTransportSpy(response: response)
        ).load(
            URL(string: "https://cdn.dummyjson.com/image")!,
            policy: .product
        )

        #expect(image.mimeType == fixture.mimeType)
        #expect(image.pixelWidth == 1)
        #expect(image.pixelHeight == 1)
    }

    @Test
    func rejectsMIMEAndSignatureDisagreement() async {
        let response = ImageHTTPResponse(
            finalURL: URL(string: "https://dummyjson.com/image")!,
            statusCode: 200,
            mimeType: "image/jpeg",
            data: ImageFixture.png
        )

        await #expect(throws: ImageLoaderError.invalidSignature) {
            try await ProductImageLoader(
                transport: ImageTransportSpy(response: response)
            ).load(
                URL(string: "https://dummyjson.com/image")!,
                policy: .product
            )
        }
    }

    @Test
    func rejectsUnsupportedMIMEBeforeDecode() async {
        let response = ImageHTTPResponse(
            finalURL: URL(string: "https://dummyjson.com/image")!,
            statusCode: 200,
            mimeType: "text/html",
            data: ImageFixture.png
        )

        await #expect(throws: ImageLoaderError.invalidMIMEType) {
            try await ProductImageLoader(
                transport: ImageTransportSpy(response: response)
            ).load(
                URL(string: "https://dummyjson.com/image")!,
                policy: .product
            )
        }
    }

    @Test
    func rejectsImageIOPixelDimensionsAbovePolicy() async {
        let response = ImageHTTPResponse(
            finalURL: URL(string: "https://dummyjson.com/image")!,
            statusCode: 200,
            mimeType: "image/png",
            data: ImageFixture.png
        )
        let policy = ImageLoadPolicy(
            allowedHosts: ["dummyjson.com"],
            timeout: .seconds(1),
            maximumEncodedBytes: 1_024,
            maximumPixelWidth: 0,
            maximumPixelHeight: 1
        )

        await #expect(throws: ImageLoaderError.dimensionsTooLarge) {
            try await ProductImageLoader(
                transport: ImageTransportSpy(response: response)
            ).load(
                URL(string: "https://dummyjson.com/image")!,
                policy: policy
            )
        }
    }

    @Test
    func timeoutCancelsAndAwaitsTransport() async {
        let transport = CancellationCooperativeImageTransport()
        let clock = AppClock(
            now: Date.init,
            monotonicNow: { ContinuousClock().now },
            sleep: { _ in }
        )

        await #expect(throws: ImageLoaderError.timedOut) {
            try await ProductImageLoader(
                transport: transport,
                clock: clock
            ).load(
                URL(string: "https://dummyjson.com/image")!,
                policy: .product
            )
        }
        #expect(await transport.wasCancelled)
    }

    @Test
    func callerCancellationIsPreservedAndStopsTransport() async {
        let transport = CancellationCooperativeImageTransport()
        let clock = AppClock(
            now: Date.init,
            monotonicNow: { ContinuousClock().now },
            sleep: { _ in try await Task.sleep(for: .seconds(60)) }
        )
        let task = Task {
            try await ProductImageLoader(
                transport: transport,
                clock: clock
            ).load(
                URL(string: "https://dummyjson.com/image")!,
                policy: .product
            )
        }
        await transport.waitUntilStarted()

        task.cancel()

        await #expect(throws: ImageLoaderError.cancelled) {
            try await task.value
        }
        #expect(await transport.wasCancelled)
    }
}

private actor ImageTransportSpy: ImageHTTPTransport {
    private(set) var callCount = 0
    private let response: ImageHTTPResponse

    init(response: ImageHTTPResponse) {
        self.response = response
    }

    func fetch(_ url: URL, policy: ImageLoadPolicy) async throws -> ImageHTTPResponse {
        _ = url
        _ = policy
        callCount += 1
        return response
    }
}

private actor CancellationCooperativeImageTransport: ImageHTTPTransport {
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var wasCancelled = false

    func fetch(_ url: URL, policy: ImageLoadPolicy) async throws -> ImageHTTPResponse {
        _ = url
        _ = policy
        started = true
        for waiter in startWaiters { waiter.resume() }
        startWaiters = []
        do {
            try await Task.sleep(for: .seconds(60))
            return .png
        } catch is CancellationError {
            wasCancelled = true
            throw CancellationError()
        }
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }
}

nonisolated enum ImageFixture {
    struct Case: Sendable, CustomTestStringConvertible {
        let mimeType: String
        let data: Data
        var testDescription: String { mimeType }
    }

    static let png = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )!
    static let jpeg = Data(base64Encoded:
        "/9j/4AAQSkZJRgABAQAASABIAAD/4QBARXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAAaADAAQAAAABAAAAAQAAAAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgAAQABAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8vLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMABgYGBgYGCgYGCg4KCgoOEg4ODg4SFxISEhISFxwXFxcXFxccHBwcHBwcHCIiIiIiIicnJycnLCwsLCwsLCwsLP/bAEMBBwcHCwoLEwoKEy4fGh8uLi4uLi4uLi4uLi4uLi4uLi4uLi4uLi4uLi4uLi4uLi4uLi4uLi4uLi4uLi4uLi4uLv/dAAQAAf/aAAwDAQACEQMRAD8A86ooor44/pE//9k="
    )!
    static let gif = Data(base64Encoded: "R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==")!
    static let webP = Data(base64Encoded: "UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEAAUAmJQBOgCHwAP7+4AAAAA==")!
    static let validCases = [
        Case(mimeType: "image/png", data: png),
        Case(mimeType: "image/jpeg", data: jpeg),
        Case(mimeType: "image/gif", data: gif),
        Case(mimeType: "image/webp", data: webP)
    ]
}

private extension ImageHTTPResponse {
    nonisolated static var png: ImageHTTPResponse {
        ImageHTTPResponse(
            finalURL: URL(string: "https://dummyjson.com/image.png")!,
            statusCode: 200,
            mimeType: "image/png",
            data: ImageFixture.png
        )
    }
}
