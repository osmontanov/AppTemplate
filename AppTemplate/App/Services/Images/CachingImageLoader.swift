import Foundation

actor CachingImageLoader: IImageLoader {
    private struct FlightKey: Hashable {
        let url: URL
        let policy: ImageLoadPolicy
    }

    private struct Flight {
        let task: Task<LoadedImage, Error>
        var waiters: Set<UInt64>
    }

    private let base: any IImageLoader
    private let maximumTotalBytes: Int
    private var cachedImagesByURL: [URL: LoadedImage] = [:]
    private var recentURLs: [URL] = []
    private var cachedTotalBytes = 0
    private var flights: [FlightKey: Flight] = [:]
    private var nextWaiterID: UInt64 = 0

    init(
        base: any IImageLoader = ProductImageLoader(),
        maximumTotalBytes: Int = 32 * 1_024 * 1_024
    ) {
        self.base = base
        self.maximumTotalBytes = max(0, maximumTotalBytes)
    }

    func load(_ url: URL, policy: ImageLoadPolicy) async throws -> LoadedImage {
        guard policy.permits(url) else {
            throw ImageLoaderError.disallowedOrigin
        }
        if let cached = cachedImagesByURL[url], satisfies(cached, policy) {
            markRecentlyUsed(url)
            return cached
        }

        let key = FlightKey(url: url, policy: policy)
        let (task, waiter) = join(key)
        // One download is shared by every caller for the same URL and policy, so
        // a caller going away must not cancel it for the others — the fetch stops
        // only once the last waiter has left. `leave` is keyed by waiter, so the
        // cancellation handler and the exit path can both call it.
        return try await withTaskCancellationHandler {
            do {
                let image = try await task.value
                leave(key, waiter: waiter)
                try Task.checkCancellation()
                return image
            } catch {
                leave(key, waiter: waiter)
                throw error
            }
        } onCancel: {
            Task { await self.leave(key, waiter: waiter) }
        }
    }

    private func join(_ key: FlightKey) -> (Task<LoadedImage, Error>, UInt64) {
        precondition(nextWaiterID < .max, "Image loader waiter identifiers exhausted")
        nextWaiterID += 1
        let waiter = nextWaiterID
        if var existing = flights[key] {
            existing.waiters.insert(waiter)
            flights[key] = existing
            return (existing.task, waiter)
        }
        let base = base
        let task = Task { try await base.load(key.url, policy: key.policy) }
        flights[key] = Flight(task: task, waiters: [waiter])
        Task { self.finish(await task.result, for: key) }
        return (task, waiter)
    }

    private func leave(_ key: FlightKey, waiter: UInt64) {
        guard var flight = flights[key] else { return }
        flight.waiters.remove(waiter)
        if flight.waiters.isEmpty {
            flights[key] = nil
            flight.task.cancel()
        } else {
            flights[key] = flight
        }
    }

    private func finish(_ result: Result<LoadedImage, Error>, for key: FlightKey) {
        flights[key] = nil
        guard case let .success(image) = result else { return }
        cache(image, for: key.url)
    }

    private func satisfies(
        _ image: LoadedImage,
        _ policy: ImageLoadPolicy
    ) -> Bool {
        image.data.count <= policy.maximumEncodedBytes &&
            image.pixelWidth <= policy.maximumPixelWidth &&
            image.pixelHeight <= policy.maximumPixelHeight
    }

    private func cache(_ image: LoadedImage, for url: URL) {
        guard image.data.count <= maximumTotalBytes else { return }
        if let replaced = cachedImagesByURL.updateValue(image, forKey: url) {
            cachedTotalBytes -= replaced.data.count
        }
        cachedTotalBytes += image.data.count
        markRecentlyUsed(url)
        while cachedTotalBytes > maximumTotalBytes, let oldest = recentURLs.first {
            recentURLs.removeFirst()
            if let evicted = cachedImagesByURL.removeValue(forKey: oldest) {
                cachedTotalBytes -= evicted.data.count
            }
        }
    }

    private func markRecentlyUsed(_ url: URL) {
        if let index = recentURLs.firstIndex(of: url) {
            recentURLs.remove(at: index)
        }
        recentURLs.append(url)
    }
}
