import Foundation

nonisolated
extension LocalNotificationEvent {
    var navigationCandidate: URL? {
        switch self {
        case let .opened(_, deepLink),
             let .action(_, _, deepLink),
             let .textAction(_, _, _, deepLink):
            deepLink
        case .foreground, .dismissed, .diagnostic:
            nil
        }
    }
}

actor LocalNotificationEventHub {
    nonisolated let navigationEvents: AsyncStream<LocalNotificationEvent>

    private let navigationContinuation: AsyncStream<LocalNotificationEvent>.Continuation
    private var publicContinuations: [
        UUID: AsyncStream<LocalNotificationEvent>.Continuation
    ] = [:]
    private var subscriptionCountWaiters: [SubscriptionCountWaiter] = []
    private var nextEventSequence: UInt64 = 0

    init() {
        let pair = AsyncStream.makeStream(
            of: LocalNotificationEvent.self,
            bufferingPolicy: .unbounded
        )
        navigationEvents = pair.stream
        navigationContinuation = pair.continuation
    }

    var activeSubscriptionCount: Int { publicContinuations.count }

    func waitUntilSubscriptionCountForTesting(_ expectedCount: Int) async {
        precondition(expectedCount >= 0, "Subscription count cannot be negative")
        guard publicContinuations.count != expectedCount else { return }
        await withCheckedContinuation { continuation in
            subscriptionCountWaiters.append(
                SubscriptionCountWaiter(
                    expectedCount: expectedCount,
                    continuation: continuation
                )
            )
        }
    }

    func events() -> AsyncStream<LocalNotificationEvent> {
        let id = UUID()
        let pair = AsyncStream.makeStream(
            of: LocalNotificationEvent.self,
            bufferingPolicy: .unbounded
        )
        pair.continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.removePublicContinuation(id: id) }
        }
        publicContinuations[id] = pair.continuation
        resumeSatisfiedSubscriptionCountWaiters()
        return pair.stream
    }

    func publish(_ event: LocalNotificationEvent) {
        precondition(nextEventSequence < UInt64.max, "Event sequence exhausted")
        let sequencedEvent = SequencedLocalNotificationEvent(
            sequence: nextEventSequence,
            event: event
        )
        nextEventSequence += 1

        if sequencedEvent.event.navigationCandidate != nil {
            navigationContinuation.yield(sequencedEvent.event)
        }

        let continuations = Array(publicContinuations.values)
        for continuation in continuations {
            continuation.yield(sequencedEvent.event)
        }
    }

    private func removePublicContinuation(id: UUID) {
        publicContinuations[id] = nil
        resumeSatisfiedSubscriptionCountWaiters()
    }

    private func resumeSatisfiedSubscriptionCountWaiters() {
        let currentCount = publicContinuations.count
        let satisfiedWaiters = subscriptionCountWaiters.filter {
            $0.expectedCount == currentCount
        }
        subscriptionCountWaiters.removeAll { $0.expectedCount == currentCount }
        for waiter in satisfiedWaiters { waiter.continuation.resume() }
    }
}

private nonisolated struct SubscriptionCountWaiter: Sendable {
    let expectedCount: Int
    let continuation: CheckedContinuation<Void, Never>
}

private nonisolated struct SequencedLocalNotificationEvent: Sendable {
    let sequence: UInt64
    let event: LocalNotificationEvent
}
