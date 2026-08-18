import Foundation
import Nuke
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import Testing
@testable import AppTemplate

struct ImageDecoderTests {
    @Test
    func decodesBytesThatPassTheValidator() throws {
        let container = try ImageDecoder(policy: .product).decode(ImageFixtures.png)
        #expect(container.image.size.width > 0)
    }

    @Test
    func refusesCachedBytesThatAreNotAnAllowlistedImage() {
        #expect(throws: ImageServiceError.invalidSignature) {
            try ImageDecoder(policy: .product).decode(Data("<svg/>".utf8))
        }
    }

    @Test
    func refusesCachedBytesOverThePixelCapBeforeDecoding() {
        let narrow = ImagePolicy(
            allowedHosts: ImagePolicy.product.allowedHosts,
            timeout: .seconds(5),
            maximumEncodedBytes: 5_000_000,
            maximumPixelSide: 0
        )
        #expect(throws: ImageServiceError.dimensionsTooLarge) {
            try ImageDecoder(policy: narrow).decode(ImageFixtures.png)
        }
    }

    @Test
    func neverProducesAPartialImage() {
        #expect(ImageDecoder(policy: .product)
            .decodePartiallyDownloadedData(ImageFixtures.png) == nil)
    }
}
