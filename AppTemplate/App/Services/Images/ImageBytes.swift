import Foundation
import ImageIO

nonisolated
struct ImageHTTPResponse: Equatable, Sendable {
    let finalURL: URL
    let statusCode: Int
    let contentType: String?
}

nonisolated
struct ImageBytes: Equatable, Sendable {
    let data: Data
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int
}

nonisolated
extension ImageBytes {
    // `response` is nil for bytes that did not arrive over HTTP on this call —
    // a disk-cache hit or decoder input — where only the byte-level contract is
    // provable. Everything reachable from the bytes alone is still checked.
    static func validated(
        _ body: Data,
        from response: ImageHTTPResponse?,
        policy: ImagePolicy
    ) throws(ImageServiceError) -> ImageBytes {
        if let response {
            guard policy.permits(response.finalURL) else {
                throw .disallowedOrigin
            }
            guard (200...299).contains(response.statusCode) else {
                throw .invalidStatus
            }
        }
        guard body.count <= policy.maximumEncodedBytes else {
            throw .responseTooLarge
        }
        guard let detected = ImageByteFormat(signatureOf: body) else {
            throw .invalidSignature
        }
        if let response {
            guard let declared = ImageByteFormat(contentType: response.contentType) else {
                throw .invalidMIMEType
            }
            guard declared == detected else {
                throw .invalidSignature
            }
        }
        let size = try pixelSize(of: body)
        guard size.width <= policy.maximumPixelSide,
              size.height <= policy.maximumPixelSide
        else {
            throw .dimensionsTooLarge
        }
        return ImageBytes(
            data: body,
            mimeType: detected.mimeType,
            pixelWidth: size.width,
            pixelHeight: size.height
        )
    }

    // Metadata only: no CGImageSourceCreateImageAtIndex, so the pixel cap is
    // proven before anything allocates a decompressed bitmap.
    private static func pixelSize(
        of data: Data
    ) throws(ImageServiceError) -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0,
              height > 0
        else {
            throw .invalidSignature
        }
        return (width, height)
    }
}
