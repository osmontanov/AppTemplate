import Foundation
import Nuke
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import Testing
@testable import AppTemplate

struct ImageServiceTests {
    private func service(
        steps: [ScriptedImageStep],
        policy: ImagePolicy = .product
    ) -> ImageService {
        ImageService.scripted(steps: steps, tracker: nil, policy: policy)
    }

    @Test
    func configurationNeverLeansOnNukeProcessWideSingletons() {
        let configuration = ImageService.configuration(
            loader: FailClosedImageDataLoader(),
            policy: .product,
            diskCache: nil,
            isRateLimiterEnabled: false
        )

        // Assigning imageCache is what flips Nuke's private "custom cache"
        // flag; reading it without assigning hands back ImageCache.shared.
        #expect(configuration.imageCache !== ImageCache.shared)
        #expect(!configuration.isResumableDataEnabled)
        #expect(!configuration.isLocalResourcesSupportEnabled)
        #expect(!configuration.isProgressiveDecodingEnabled)
        #expect(configuration.maximumResponseDataSize == ImagePolicy.product.maximumEncodedBytes)
        #expect(configuration.dataCache == nil)
    }

    @Test
    func configurationInstallsOurDecoderRatherThanTheSharedRegistry() throws {
        let configuration = ImageService.configuration(
            loader: FailClosedImageDataLoader(),
            policy: .product,
            diskCache: nil,
            isRateLimiterEnabled: false
        )
        let context = ImageDecodingContext(
            request: ImageRequest(url: ImageFixtures.allowedURL),
            data: ImageFixtures.png,
            isCompleted: true,
            urlResponse: nil
        )

        #expect(configuration.makeImageDecoder(context) is ImageDecoder)
    }

    @Test
    func twoServicesNeverShareAPipelineOrACache() {
        let first = ImageService.failClosed()
        let second = ImageService.failClosed()

        #expect(first !== second)
        #expect(first.kind == .failClosed)
        #expect(second.kind == .failClosed)
    }

    @Test
    func imageDecodesASeededResponse() async throws {
        let images = service(steps: [.png(ImageFixtures.allowedURL, body: ImageFixtures.png)])

        let image = try await images.image(for: ImageFixtures.allowedURL)

        #expect(image.size.width > 0)
    }

    @Test
    func bytesCarryTheOriginalEncodedBytesMIMETypeAndPixelSize() async throws {
        let images = service(steps: [.png(ImageFixtures.allowedURL, body: ImageFixtures.png)])

        let bytes = try await images.bytes(for: ImageFixtures.allowedURL)

        #expect(bytes.data == ImageFixtures.png)
        #expect(bytes.mimeType == "image/png")
        #expect(bytes.pixelWidth == 1)
        #expect(bytes.pixelHeight == 1)
    }

    @Test
    func aDisallowedOriginNeverReachesTheLoader() async {
        let probe = ImageServiceProbe()

        await #expect(throws: ImageServiceError.disallowedOrigin) {
            _ = try await probe.service.image(for: ImageFixtures.foreignURL)
        }
        await #expect(throws: ImageServiceError.disallowedOrigin) {
            _ = try await probe.service.bytes(for: ImageFixtures.foreignURL)
        }
        // The facade refuses before anything downstream is asked, so removing
        // the loader's own check cannot make this pass.
        #expect(probe.requestedURLs.isEmpty)
    }

    @Test
    func aSeededResponseThatFailsValidationSurfacesTheValidatorReason() async {
        let images = service(steps: [ScriptedImageStep(
            url: ImageFixtures.allowedURL,
            outcome: .response(
                statusCode: 200,
                contentType: "image/png",
                body: Data("<svg/>".utf8)
            )
        )])

        await #expect(throws: ImageServiceError.invalidSignature) {
            _ = try await images.image(for: ImageFixtures.allowedURL)
        }
    }

    @Test
    func failClosedRefusesEveryURLWithoutTouchingTheNetwork() async {
        let images = ImageService.failClosed()

        await #expect(throws: ImageServiceError.transport) {
            _ = try await images.image(for: ImageFixtures.allowedURL)
        }
        await #expect(throws: ImageServiceError.transport) {
            _ = try await images.bytes(for: ImageFixtures.allowedURL)
        }
    }

    @Test
    func cancellingTheCallingTaskSurfacesAsCancelledRatherThanTransport() async throws {
        let images = service(steps: [.png(ImageFixtures.allowedURL, body: ImageFixtures.png)])
        let task = Task { try await images.image(for: ImageFixtures.allowedURL) }
        task.cancel()

        await #expect(throws: ImageServiceError.cancelled) {
            _ = try await task.value
        }
    }

    @Test
    func aLoadedImageIsAvailableSynchronouslyAfterwards() async throws {
        let images = service(steps: [.png(ImageFixtures.allowedURL, body: ImageFixtures.png)])

        // Nothing is cached before the first load.
        #expect(images.cachedImage(for: ImageFixtures.allowedURL) == nil)
        _ = try await images.image(for: ImageFixtures.allowedURL)

        // A view rebuilt after this point renders on its first frame instead of
        // blanking and awaiting the pipeline again.
        #expect(images.cachedImage(for: ImageFixtures.allowedURL) != nil)
    }

    @Test
    func theSynchronousCacheReadHonoursTheOriginAllowlist() {
        let images = service(steps: [])

        #expect(images.cachedImage(for: ImageFixtures.foreignURL) == nil)
    }

    @Test
    func bytesDoNotPopulateTheDecodedImageCache() async throws {
        let images = service(steps: [.png(ImageFixtures.allowedURL, body: ImageFixtures.png)])

        _ = try await images.bytes(for: ImageFixtures.allowedURL)

        // The reminder path decodes nothing, so it must not pretend a decoded
        // image is available to the views.
        #expect(images.cachedImage(for: ImageFixtures.allowedURL) == nil)
    }

    @Test
    func liveIsReachableWithoutADiskCacheAndReportsItsKind() {
        let images = ImageService.live(diskCache: nil)

        #expect(images.kind == .live)
    }
}
