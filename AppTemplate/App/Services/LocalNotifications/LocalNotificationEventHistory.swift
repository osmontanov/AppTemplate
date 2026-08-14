import Foundation

nonisolated protocol ILocalNotificationEventReading: Sendable {
    func records() async -> [LocalNotificationEventRecord]
    func updates() async -> AsyncStream<[LocalNotificationEventRecord]>
    func clear() async
}

actor LocalNotificationEventHistory: ILocalNotificationEventReading {
    private let clock: AppClock
    private let capacity: Int
    private var storedRecords: [LocalNotificationEventRecord] = []
    private var nextID: UInt64 = 0
    private var continuations: [
        UUID: AsyncStream<[LocalNotificationEventRecord]>.Continuation
    ] = [:]
    private var subscriptionCountWaiters: [HistorySubscriptionCountWaiter] = []

    init(clock: AppClock, capacity: Int = 100) {
        precondition(capacity > 0, "History capacity must be positive")
        self.clock = clock
        self.capacity = capacity
    }

    var activeSubscriptionCount: Int { continuations.count }

    func records() -> [LocalNotificationEventRecord] { storedRecords }

    func updates() -> AsyncStream<[LocalNotificationEventRecord]> {
        let id = UUID()
        let pair = AsyncStream.makeStream(
            of: [LocalNotificationEventRecord].self,
            bufferingPolicy: .bufferingNewest(1)
        )
        pair.continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.removeContinuation(id: id) }
        }
        continuations[id] = pair.continuation
        pair.continuation.yield(storedRecords)
        resumeSatisfiedWaiters()
        return pair.stream
    }

    func append(_ event: LocalNotificationEvent) {
        precondition(nextID < UInt64.max, "History record identifier exhausted")
        storedRecords.append(LocalNotificationEventRecord(
            id: nextID,
            timestamp: clock.now(),
            summary: LocalNotificationEventSummary(event: event)
        ))
        nextID += 1
        if storedRecords.count > capacity {
            storedRecords.removeFirst(storedRecords.count - capacity)
        }
        yieldSnapshot()
    }

    func clear() {
        storedRecords.removeAll(keepingCapacity: true)
        yieldSnapshot()
    }

    func waitUntilSubscriptionCountForTesting(_ expectedCount: Int) async {
        precondition(expectedCount >= 0, "Subscription count cannot be negative")
        guard continuations.count != expectedCount else { return }
        await withCheckedContinuation { continuation in
            subscriptionCountWaiters.append(.init(
                expectedCount: expectedCount,
                continuation: continuation
            ))
        }
    }

    private func yieldSnapshot() {
        let snapshot = storedRecords
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func removeContinuation(id: UUID) {
        continuations[id] = nil
        resumeSatisfiedWaiters()
    }

    private func resumeSatisfiedWaiters() {
        let count = continuations.count
        let satisfied = subscriptionCountWaiters.filter { $0.expectedCount == count }
        subscriptionCountWaiters.removeAll { $0.expectedCount == count }
        for waiter in satisfied { waiter.continuation.resume() }
    }
}

private nonisolated struct HistorySubscriptionCountWaiter: Sendable {
    let expectedCount: Int
    let continuation: CheckedContinuation<Void, Never>
}
