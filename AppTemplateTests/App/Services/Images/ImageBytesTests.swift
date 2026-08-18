import Foundation
import Testing
@testable import AppTemplate

struct ImageBytesTests {
    private let policy = ImagePolicy.product

    private func response(
        url: URL = ImageFixtures.allowedURL,
        status: Int = 200,
        contentType: String? = "image/png"
    ) -> ImageHTTPResponse {
        ImageHTTPResponse(finalURL: url, statusCode: status, contentType: contentType)
    }

    @Test
    func acceptsAWellFormedResponseAndReportsItsRealPixelSize() throws {
        let bytes = try ImageBytes.validated(
            ImageFixtures.png,
            from: response(),
            policy: policy
        )
        #expect(bytes.data == ImageFixtures.png)
        #expect(bytes.mimeType == "image/png")
        #expect(bytes.pixelWidth == 1)
        #expect(bytes.pixelHeight == 1)
    }

    @Test
    func rejectsAFinalURLOutsideTheAllowlistEvenWhenTheBytesAreValid() {
        #expect(throws: ImageServiceError.disallowedOrigin) {
            try ImageBytes.validated(
                ImageFixtures.png,
                from: response(url: ImageFixtures.foreignURL),
                policy: policy
            )
        }
    }

    @Test(arguments: [301, 400, 404, 500])
    func rejectsAnyStatusOutsideTheSuccessRange(_ status: Int) {
        #expect(throws: ImageServiceError.invalidStatus) {
            try ImageBytes.validated(
                ImageFixtures.png,
                from: response(status: status),
                policy: policy
            )
        }
    }

    @Test
    func rejectsABodyOverTheEncodedCap() {
        let small = ImagePolicy(
            allowedHosts: policy.allowedHosts,
            timeout: policy.timeout,
            maximumEncodedBytes: ImageFixtures.png.count - 1,
            maximumPixelSide: policy.maximumPixelSide
        )
        #expect(throws: ImageServiceError.responseTooLarge) {
            try ImageBytes.validated(ImageFixtures.png, from: response(), policy: small)
        }
    }

    @Test
    func rejectsAContentTypeOutsideTheAllowlist() {
        #expect(throws: ImageServiceError.invalidMIMEType) {
            try ImageBytes.validated(
                ImageFixtures.png,
                from: response(contentType: "image/svg+xml"),
                policy: policy
            )
        }
        #expect(throws: ImageServiceError.invalidMIMEType) {
            try ImageBytes.validated(
                ImageFixtures.png,
                from: response(contentType: nil),
                policy: policy
            )
        }
    }

    @Test
    func rejectsBytesWhoseSignatureContradictsTheDeclaredType() {
        #expect(throws: ImageServiceError.invalidSignature) {
            try ImageBytes.validated(
                ImageFixtures.png,
                from: response(contentType: "image/jpeg"),
                policy: policy
            )
        }
    }

    @Test
    func rejectsBytesWithNoRecognisedSignatureBeforeLookingAtTheHeader() {
        #expect(throws: ImageServiceError.invalidSignature) {
            try ImageBytes.validated(
                Data("<svg xmlns=\"http://www.w3.org/2000/svg\"/>".utf8),
                from: response(contentType: "image/png"),
                policy: policy
            )
        }
    }

    @Test
    func rejectsPixelDimensionsOverTheCapWithoutDecoding() {
        let narrow = ImagePolicy(
            allowedHosts: policy.allowedHosts,
            timeout: policy.timeout,
            maximumEncodedBytes: policy.maximumEncodedBytes,
            maximumPixelSide: 0
        )
        #expect(throws: ImageServiceError.dimensionsTooLarge) {
            try ImageBytes.validated(ImageFixtures.png, from: response(), policy: narrow)
        }
    }

    @Test
    func withoutAResponseOnlyTheByteLevelContractIsChecked() throws {
        let bytes = try ImageBytes.validated(ImageFixtures.png, from: nil, policy: policy)
        #expect(bytes.mimeType == "image/png")

        // A disk-cache hit still cannot smuggle in bytes that are not an image.
        #expect(throws: ImageServiceError.invalidSignature) {
            try ImageBytes.validated(Data("not an image".utf8), from: nil, policy: policy)
        }
    }

    @Test
    func truncatedHeaderBytesAreRejectedRatherThanGuessed() {
        #expect(throws: ImageServiceError.invalidSignature) {
            try ImageBytes.validated(
                ImageFixtures.png.prefix(9),
                from: response(),
                policy: policy
            )
        }
    }
}
