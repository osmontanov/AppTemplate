import Foundation

@MainActor
final class LocalNotificationNavigationCoordinator {
    private let eventHub: LocalNotificationEventHub
    private let parser: DeepLinkParser
    private var registrations: [UUID: SceneRegistration] = [:]
    private var queuedURLs: [URL] = []
    private var nextEligibilitySequence: UInt64 = 0
    private var consumerTask: Task<Void, Never>?

    init(
        eventHub: LocalNotificationEventHub,
        parser: DeepLinkParser
    ) {
        self.eventHub = eventHub
        self.parser = parser
    }

    deinit {
        consumerTask?.cancel()
    }

    func register(
        id: UUID,
        receiver: any LocalNotificationSceneReceiving
    ) {
        registrations[id] = SceneRegistration(receiver: receiver)
    }

    func unregister(id: UUID) {
        registrations[id] = nil
    }

    func setEligible(_ isEligible: Bool, id: UUID) {
        pruneDeallocatedReceivers()
        guard var registration = registrations[id] else { return }

        if isEligible {
            precondition(
                nextEligibilitySequence < UInt64.max,
                "Local notification scene eligibility sequence exhausted"
            )
            registration.eligibilitySequence = nextEligibilitySequence
            nextEligibilitySequence += 1
        } else {
            registration.eligibilitySequence = nil
        }
        registrations[id] = registration

        if isEligible {
            drainQueuedURLsIfPossible()
        }
    }

    func start() {
        guard consumerTask == nil else { return }
        let navigationEvents = eventHub.navigationEvents
        consumerTask = Task { @MainActor [weak self, navigationEvents] in
            for await event in navigationEvents {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                await self.consume(event)
            }
        }
    }

    private func consume(_ event: LocalNotificationEvent) async {
        guard let candidate = routeCandidate(from: event) else { return }

        guard case .success = parser.parse(candidate.url) else {
            await eventHub.publish(
                .diagnostic(
                    LocalNotificationDiagnostic(
                        id: candidate.requestID,
                        reason: .invalidDeepLink
                    )
                )
            )
            return
        }

        guard let receiver = latestEligibleReceiver() else {
            queuedURLs.append(candidate.url)
            return
        }
        receiver.receiveLocalNotificationURL(candidate.url)
    }

    private func routeCandidate(
        from event: LocalNotificationEvent
    ) -> (requestID: LocalNotificationID, url: URL)? {
        switch event {
        case let .opened(notification, deepLink),
             let .action(notification, _, deepLink),
             let .textAction(notification, _, _, deepLink):
            guard let deepLink else { return nil }
            return (notification.id, deepLink)
        case .foreground, .dismissed, .diagnostic:
            return nil
        }
    }

    private func drainQueuedURLsIfPossible() {
        guard !queuedURLs.isEmpty,
              let receiver = latestEligibleReceiver() else {
            return
        }

        let urls = queuedURLs
        queuedURLs.removeAll(keepingCapacity: true)
        for url in urls {
            receiver.receiveLocalNotificationURL(url)
        }
    }

    private func latestEligibleReceiver()
        -> (any LocalNotificationSceneReceiving)? {
        pruneDeallocatedReceivers()
        var selectedReceiver: (any LocalNotificationSceneReceiving)?
        var selectedSequence: UInt64?

        for registration in registrations.values {
            guard let receiver = registration.receiver.value,
                  let sequence = registration.eligibilitySequence else {
                continue
            }
            if let selectedSequence, sequence <= selectedSequence {
                continue
            } else {
                selectedReceiver = receiver
                selectedSequence = sequence
            }
        }
        return selectedReceiver
    }

    private func pruneDeallocatedReceivers() {
        registrations = registrations.filter { $0.value.receiver.value != nil }
    }
}

@MainActor
private struct SceneRegistration {
    let receiver: WeakSceneReceiver
    var eligibilitySequence: UInt64?

    init(receiver: any LocalNotificationSceneReceiving) {
        self.receiver = WeakSceneReceiver(receiver)
    }
}

@MainActor
private final class WeakSceneReceiver {
    weak var value: (any LocalNotificationSceneReceiving)?

    init(_ value: any LocalNotificationSceneReceiving) {
        self.value = value
    }
}
