import Foundation
import ImageIO

nonisolated
struct ProductImageLoader: IImageLoader {
    private enum RaceResult: Sendable {
        case response(ImageHTTPResponse)
        case timeout
    }

    private let transport: any IImageHTTPTransport
    private let clock: AppClock

    init(
        transport: any IImageHTTPTransport = URLSessionImageHTTPTransport(),
        clock: AppClock = .live
    ) {
        self.transport = transport
        self.clock = clock
    }

    func load(_ url: URL, policy: ImageLoadPolicy) async throws -> LoadedImage {
        guard url.scheme != nil, url.host != nil else {
            throw ImageLoaderError.invalidURL
        }
        guard policy.permits(url) else {
            throw ImageLoaderError.disallowedOrigin
        }
        guard policy.maximumEncodedBytes >= 0,
              policy.maximumPixelWidth >= 0,
              policy.maximumPixelHeight >= 0,
              policy.timeout > .zero
        else {
            throw ImageLoaderError.transport
        }

        let response: ImageHTTPResponse
        do {
            response = try await raceFetch(url, policy: policy)
        } catch let error as ImageLoaderError {
            throw error
        } catch is CancellationError {
            throw ImageLoaderError.cancelled
        } catch {
            throw ImageLoaderError.transport
        }

        guard (200...299).contains(response.statusCode) else {
            throw ImageLoaderError.invalidStatus
        }
        guard policy.permits(response.finalURL) else {
            throw ImageLoaderError.disallowedOrigin
        }
        guard response.data.count <= policy.maximumEncodedBytes else {
            throw ImageLoaderError.responseTooLarge
        }

        let mimeType = try normalizedMIMEType(response.mimeType)
        guard signature(of: response.data) == mimeType else {
            throw ImageLoaderError.invalidSignature
        }
        let dimensions = try dimensions(of: response.data)
        guard dimensions.width <= policy.maximumPixelWidth,
              dimensions.height <= policy.maximumPixelHeight
        else {
            throw ImageLoaderError.dimensionsTooLarge
        }

        return LoadedImage(
            data: response.data,
            mimeType: mimeType,
            pixelWidth: dimensions.width,
            pixelHeight: dimensions.height
        )
    }

    private func raceFetch(
        _ url: URL,
        policy: ImageLoadPolicy
    ) async throws -> ImageHTTPResponse {
        try await withThrowingTaskGroup(of: RaceResult.self) { group in
            group.addTask {
                .response(try await transport.fetch(url, policy: policy))
            }
            group.addTask {
                try await clock.sleep(policy.timeout)
                return .timeout
            }

            do {
                guard let first = try await group.next() else {
                    throw ImageLoaderError.transport
                }
                group.cancelAll()
                while (try? await group.next()) != nil {}

                switch first {
                case let .response(response):
                    return response
                case .timeout:
                    throw ImageLoaderError.timedOut
                }
            } catch {
                group.cancelAll()
                while (try? await group.next()) != nil {}
                if Task.isCancelled || error is CancellationError {
                    throw ImageLoaderError.cancelled
                }
                throw error
            }
        }
    }

    private func normalizedMIMEType(_ value: String?) throws -> String {
        guard let mediaType = value?
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            ["image/png", "image/jpeg", "image/gif", "image/webp"].contains(mediaType)
        else {
            throw ImageLoaderError.invalidMIMEType
        }
        return mediaType
    }

    private func signature(of data: Data) -> String? {
        let bytes = [UInt8](data.prefix(12))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return "image/png"
        }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "image/jpeg"
        }
        if bytes.starts(with: Array("GIF87a".utf8)) ||
            bytes.starts(with: Array("GIF89a".utf8)) {
            return "image/gif"
        }
        if bytes.count >= 12,
           Array(bytes[0..<4]) == Array("RIFF".utf8),
           Array(bytes[8..<12]) == Array("WEBP".utf8) {
            return "image/webp"
        }
        return nil
    }

    private func dimensions(of data: Data) throws -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0,
              height > 0
        else {
            throw ImageLoaderError.invalidSignature
        }
        return (width, height)
    }
}
