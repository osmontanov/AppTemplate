import Foundation

actor LocalNotificationEventHub {
    private let history: LocalNotificationEventHistory
    private let publicCapacity: Int
    private var publicContinuations: [
        UUID: AsyncStream<LocalNotificationEvent>.Continuation
    ] = [:]
    private var subscriptionCountWaiters: [EventHubSubscriptionCountWaiter] = []

    init(history: LocalNotificationEventHistory, publicCapacity: Int = 100) {
        precondition(publicCapacity > 0, "Event capacity must be positive")
        self.history = history
        self.publicCapacity = publicCapacity
    }

    var activeSubscriptionCount: Int { publicContinuations.count }

    func events() -> AsyncStream<LocalNotificationEvent> {
        let id = UUID()
        let pair = AsyncStream.makeStream(
            of: LocalNotificationEvent.self,
            bufferingPolicy: .bufferingNewest(publicCapacity)
        )
        pair.continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.removePublicContinuation(id: id) }
        }
        publicContinuations[id] = pair.continuation
        resumeSatisfiedSubscriptionCountWaiters()
        return pair.stream
    }

    func publish(_ event: LocalNotificationEvent) async {
        await history.append(event)
        for continuation in publicContinuations.values {
            continuation.yield(event)
        }
    }

    func waitUntilSubscriptionCountForTesting(_ expectedCount: Int) async {
        precondition(expectedCount >= 0, "Subscription count cannot be negative")
        guard publicContinuations.count != expectedCount else { return }
        await withCheckedContinuation { continuation in
            subscriptionCountWaiters.append(.init(
                expectedCount: expectedCount,
                continuation: continuation
            ))
        }
    }

    private func removePublicContinuation(id: UUID) {
        publicContinuations[id] = nil
        resumeSatisfiedSubscriptionCountWaiters()
    }

    private func resumeSatisfiedSubscriptionCountWaiters() {
        let currentCount = publicContinuations.count
        let satisfied = subscriptionCountWaiters.filter {
            $0.expectedCount == currentCount
        }
        subscriptionCountWaiters.removeAll { $0.expectedCount == currentCount }
        for waiter in satisfied { waiter.continuation.resume() }
    }
}

private nonisolated struct EventHubSubscriptionCountWaiter: Sendable {
    let expectedCount: Int
    let continuation: CheckedContinuation<Void, Never>
}
