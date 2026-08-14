import Foundation

@MainActor
final class LocalNotificationNavigationCoordinator {
    private let queueCapacity: Int
    private let diagnosticSink: @MainActor @Sendable (NotificationQueueDiagnostic) async -> Void
    private var registrations: [UUID: NotificationSceneRegistration] = [:]
    private var queue: [NotificationNavigationCommand] = []
    private var nextEligibilitySequence: UInt64 = 0
    private var droppedCount = 0
    private var isDraining = false

    init(
        queueCapacity: Int = 32,
        diagnosticSink: @escaping @MainActor @Sendable (
            NotificationQueueDiagnostic
        ) async -> Void = { _ in }
    ) {
        precondition(queueCapacity > 0, "Notification queue capacity must be positive")
        self.queueCapacity = queueCapacity
        self.diagnosticSink = diagnosticSink
    }

    func register(id: UUID, receiver: any LocalNotificationSceneReceiving) {
        registrations[id] = NotificationSceneRegistration(receiver: receiver)
    }

    func unregister(id: UUID) {
        registrations[id] = nil
    }

    func setReadiness(_ readiness: NotificationSceneReadiness, id: UUID) {
        pruneDeallocatedReceivers()
        guard var registration = registrations[id] else { return }
        registration.readiness = readiness
        if readiness.isEligible {
            precondition(
                nextEligibilitySequence < UInt64.max,
                "Notification scene eligibility sequence exhausted"
            )
            registration.eligibilitySequence = nextEligibilitySequence
            nextEligibilitySequence += 1
        } else {
            registration.eligibilitySequence = nil
        }
        registrations[id] = registration
        guard readiness.isEligible else { return }
        Task { @MainActor [weak self] in await self?.drainIfPossible() }
    }

    func deliver(_ command: NotificationNavigationCommand) async {
        queue.append(command)
        if queue.count > queueCapacity {
            queue.removeFirst(queue.count - queueCapacity)
            droppedCount += 1
            await diagnosticSink(.queueOverflow(droppedCount: droppedCount))
        }
        await drainIfPossible()
    }

    private func drainIfPossible() async {
        guard !isDraining else { return }
        isDraining = true
        defer { isDraining = false }

        while !queue.isEmpty, let receiver = latestEligibleReceiver() {
            let command = queue.removeFirst()
            await receiver.receiveNotificationCommand(command)
        }
    }

    private func latestEligibleReceiver() -> (any LocalNotificationSceneReceiving)? {
        pruneDeallocatedReceivers()
        return registrations.values
            .filter { $0.readiness.isEligible && $0.receiver.value != nil }
            .max { lhs, rhs in
                (lhs.eligibilitySequence ?? 0) < (rhs.eligibilitySequence ?? 0)
            }?
            .receiver.value
    }

    private func pruneDeallocatedReceivers() {
        registrations = registrations.filter { $0.value.receiver.value != nil }
    }
}

@MainActor
private struct NotificationSceneRegistration {
    let receiver: WeakNotificationSceneReceiver
    var readiness = NotificationSceneReadiness(
        isRestored: false,
        isMain: false,
        isReady: false,
        isPlatformEligible: false
    )
    var eligibilitySequence: UInt64?

    init(receiver: any LocalNotificationSceneReceiving) {
        self.receiver = WeakNotificationSceneReceiver(receiver)
    }
}

@MainActor
private final class WeakNotificationSceneReceiver {
    weak var value: (any LocalNotificationSceneReceiving)?
    init(_ value: any LocalNotificationSceneReceiving) { self.value = value }
}
