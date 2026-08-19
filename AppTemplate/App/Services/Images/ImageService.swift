import Foundation
import Nuke

nonisolated
final class ImageService: IImageBytesLoading, Sendable {
    enum Kind: Equatable, Sendable {
        case live
        case scripted
        case failClosed
    }

    let kind: Kind
    private let pipeline: ImagePipeline
    private let policy: ImagePolicy

    init(pipeline: ImagePipeline, policy: ImagePolicy, kind: Kind) {
        self.pipeline = pipeline
        self.policy = policy
        self.kind = kind
    }

    static func live(
        policy: ImagePolicy = .product,
        clock: AppClock = .live,
        diskCache: (any DataCaching)? = ImageDiskCache.live()
    ) -> ImageService {
        ImageService(
            pipeline: ImagePipeline(configuration: configuration(
                loader: ImageDataLoader(policy: policy, clock: clock),
                policy: policy,
                diskCache: diskCache,
                isRateLimiterEnabled: true
            )),
            policy: policy,
            kind: .live
        )
    }

    static func failClosed(policy: ImagePolicy = .product) -> ImageService {
        ImageService(
            pipeline: ImagePipeline(configuration: configuration(
                loader: FailClosedImageDataLoader(),
                policy: policy,
                diskCache: nil,
                isRateLimiterEnabled: false
            )),
            policy: policy,
            kind: .failClosed
        )
    }

    static func configuration(
        loader: any DataLoading,
        policy: ImagePolicy,
        diskCache: (any DataCaching)?,
        isRateLimiterEnabled: Bool
    ) -> ImagePipeline.Configuration {
        var configuration = ImagePipeline.Configuration(dataLoader: loader)
        // Assigning is what flips Nuke's private isCustomImageCacheProvided flag;
        // merely reading the property hands back the process-wide shared cache.
        configuration.imageCache = ImageCache(costLimit: 32 * 1_024 * 1_024)
        configuration.dataCache = diskCache
        configuration.dataCachePolicy = .storeOriginalData
        configuration.makeImageDecoder = { _ in ImageDecoder(policy: policy) }
        configuration.isProgressiveDecodingEnabled = false
        configuration.isLocalResourcesSupportEnabled = false
        configuration.isResumableDataEnabled = false
        configuration.isRateLimiterEnabled = isRateLimiterEnabled
        configuration.maximumResponseDataSize = policy.maximumEncodedBytes
        return configuration
    }

    // Synchronous, so a view that already has the image can render it on its
    // first frame instead of blanking and awaiting an actor hop. A miss is
    // silent: the caller falls back to image(for:).
    func cachedImage(for url: URL) -> AppImage? {
        guard policy.permits(url) else { return nil }
        return pipeline.cache[ImageRequest(url: url)]?.image
    }

    func image(for url: URL) async throws(ImageServiceError) -> AppImage {
        guard policy.permits(url) else { throw .disallowedOrigin }
        do {
            return try await pipeline.image(for: ImageRequest(url: url))
        } catch {
            throw ImageServiceError(error)
        }
    }

    func bytes(for url: URL) async throws(ImageServiceError) -> ImageBytes {
        guard policy.permits(url) else { throw .disallowedOrigin }
        let data: Data
        do {
            (data, _) = try await pipeline.data(for: ImageRequest(url: url))
        } catch {
            throw ImageServiceError(error)
        }
        return try ImageBytes.validated(data, from: nil, policy: policy)
    }
}
