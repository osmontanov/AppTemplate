import Foundation
import Testing
@testable import AppTemplate

struct CachingImageLoaderTests {
    private let policy = ImageLoadPolicy.product
    private let url = URL(string: "https://cdn.dummyjson.com/one.png")!
    private let otherURL = URL(string: "https://cdn.dummyjson.com/two.png")!

    @Test func repeatedLoadServesCachedImageWithoutSecondBaseCall() async throws {
        let base = ControlledImageLoader(results: [
            .success(Self.image(bytes: 8))
        ])
        let loader = CachingImageLoader(base: base)

        let first = try await loader.load(url, policy: policy)
        let second = try await loader.load(url, policy: policy)

        #expect(first == second)
        #expect(await base.loadCount == 1)
    }

    @Test func concurrentLoadsOfOneURLJoinSingleBaseLoad() async throws {
        let base = ControlledImageLoader(
            results: [.success(Self.image(bytes: 8))],
            suspendFirstLoad: true
        )
        let loader = CachingImageLoader(base: base)

        async let first = loader.load(url, policy: policy)
        await base.waitUntilFirstLoadStarts()
        // Joins while the first load is still suspended, so a passing result
        // cannot come from the cache.
        async let second = loader.load(url, policy: policy)
        for _ in 0..<10 { await Task.yield() }
        #expect(await base.loadCount == 1)

        await base.releaseFirstLoad()
        let images = try await (first, second)

        #expect(images.0 == images.1)
        #expect(await base.loadCount == 1)
    }

    @Test func cancellingTheOnlyWaiterCancelsTheSharedDownload() async throws {
        let base = ControlledImageLoader(
            results: [.success(Self.image(bytes: 8))],
            suspendFirstLoad: true
        )
        let loader = CachingImageLoader(base: base)

        let load = Task { try await loader.load(url, policy: policy) }
        await base.waitUntilFirstLoadStarts()
        load.cancel()
        await base.releaseFirstLoad()

        await #expect(throws: CancellationError.self) { try await load.value }
    }

    @Test func cancellingOneWaiterLetsTheOtherFinish() async throws {
        let base = ControlledImageLoader(
            results: [.success(Self.image(bytes: 8))],
            suspendFirstLoad: true
        )
        let loader = CachingImageLoader(base: base)

        let cancelled = Task { try await loader.load(url, policy: policy) }
        await base.waitUntilFirstLoadStarts()
        let survivor = Task { try await loader.load(url, policy: policy) }
        for _ in 0..<10 { await Task.yield() }
        cancelled.cancel()
        await base.releaseFirstLoad()

        #expect(try await survivor.value == Self.image(bytes: 8))
        #expect(await base.loadCount == 1)
    }

    @Test func failuresAreNotCached() async throws {
        let base = ControlledImageLoader(results: [
            .failure(ImageLoaderError.transport),
            .success(Self.image(bytes: 8))
        ])
        let loader = CachingImageLoader(base: base)

        await #expect(throws: ImageLoaderError.transport) {
            _ = try await loader.load(url, policy: policy)
        }
        _ = try await loader.load(url, policy: policy)

        #expect(await base.loadCount == 2)
    }

    @Test func exceedingTotalBytesEvictsLeastRecentlyUsedImage() async throws {
        let base = ControlledImageLoader(results: [
            .success(Self.image(bytes: 24)),
            .success(Self.image(bytes: 24)),
            .success(Self.image(bytes: 24))
        ])
        let loader = CachingImageLoader(base: base, maximumTotalBytes: 32)

        _ = try await loader.load(url, policy: policy)
        _ = try await loader.load(otherURL, policy: policy)
        _ = try await loader.load(url, policy: policy)

        #expect(await base.loadCount == 3)
    }

    @Test func evictAllDropsCachedBytesAndReloadsOnDemand() async throws {
        let base = ControlledImageLoader(results: [
            .success(Self.image(bytes: 8)),
            .success(Self.image(bytes: 8))
        ])
        let loader = CachingImageLoader(base: base)

        _ = try await loader.load(url, policy: policy)
        _ = try await loader.load(url, policy: policy)
        #expect(await base.loadCount == 1)

        await loader.evictAll()
        _ = try await loader.load(url, policy: policy)

        #expect(await base.loadCount == 2)
    }

    @Test func disallowedURLIsRejectedWithoutBaseCall() async {
        let base = ControlledImageLoader(results: [])
        let loader = CachingImageLoader(base: base)

        await #expect(throws: ImageLoaderError.disallowedOrigin) {
            _ = try await loader.load(
                URL(string: "https://evil.example/one.png")!,
                policy: policy
            )
        }
        #expect(await base.loadCount == 0)
    }

    private static func image(bytes: Int) -> LoadedImage {
        LoadedImage(
            data: Data(repeating: 0x1, count: bytes),
            mimeType: "image/png",
            pixelWidth: 1,
            pixelHeight: 1
        )
    }
}

private actor ControlledImageLoader: IImageLoader {
    private var results: [Result<LoadedImage, ImageLoaderError>]
    private let suspendFirstLoad: Bool
    private(set) var loadCount = 0
    private var firstLoadContinuation: CheckedContinuation<Void, Never>?
    private var firstLoadStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var didStartFirstLoad = false

    init(
        results: [Result<LoadedImage, ImageLoaderError>],
        suspendFirstLoad: Bool = false
    ) {
        self.results = results
        self.suspendFirstLoad = suspendFirstLoad
    }

    func load(_ url: URL, policy: ImageLoadPolicy) async throws -> LoadedImage {
        loadCount += 1
        if suspendFirstLoad, !didStartFirstLoad {
            didStartFirstLoad = true
            let waiters = firstLoadStartWaiters
            firstLoadStartWaiters.removeAll()
            for waiter in waiters { waiter.resume() }
            await withCheckedContinuation { firstLoadContinuation = $0 }
        }
        guard !results.isEmpty else { throw ImageLoaderError.transport }
        return try results.removeFirst().get()
    }

    func waitUntilFirstLoadStarts() async {
        guard !didStartFirstLoad else { return }
        await withCheckedContinuation { firstLoadStartWaiters.append($0) }
    }

    func releaseFirstLoad() {
        firstLoadContinuation?.resume()
        firstLoadContinuation = nil
    }
}
