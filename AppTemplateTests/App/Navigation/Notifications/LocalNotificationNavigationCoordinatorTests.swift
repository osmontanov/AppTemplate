import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct LocalNotificationNavigationCoordinatorTests {
    @Test(.timeLimit(.minutes(1)))
    func overflowKeepsNewestThirtyTwoAndReportsCumulativeDrops() async {
        let diagnostics = QueueDiagnosticSpy()
        let coordinator = LocalNotificationNavigationCoordinator(queueCapacity: 32) {
            diagnostics.record($0)
        }
        for id in 1...34 {
            await coordinator.deliver(.navigate(.openProduct(id)))
        }
        let receiver = NotificationCommandReceiverSpy()
        let id = UUID()
        coordinator.register(id: id, receiver: receiver)
        coordinator.setReadiness(.eligible, id: id)
        await receiver.waitForCount(32)

        #expect(receiver.productIDs == Array(3...34))
        #expect(diagnostics.values == [
            .queueOverflow(droppedCount: 1),
            .queueOverflow(droppedCount: 2)
        ])
    }

    @Test(.timeLimit(.minutes(1)))
    func allFourGatesAndLatestEligibleSceneControlDelivery() async {
        let coordinator = LocalNotificationNavigationCoordinator()
        let first = NotificationCommandReceiverSpy()
        let second = NotificationCommandReceiverSpy()
        let firstID = UUID()
        let secondID = UUID()
        coordinator.register(id: firstID, receiver: first)
        coordinator.register(id: secondID, receiver: second)

        let ineligible: [NotificationSceneReadiness] = [
            .init(isRestored: false, isMain: true, isReady: true, isPlatformEligible: true),
            .init(isRestored: true, isMain: false, isReady: true, isPlatformEligible: true),
            .init(isRestored: true, isMain: true, isReady: false, isPlatformEligible: true),
            .init(isRestored: true, isMain: true, isReady: true, isPlatformEligible: false)
        ]
        for readiness in ineligible {
            coordinator.setReadiness(readiness, id: firstID)
            await coordinator.deliver(.navigate(.openProduct(1)))
        }
        #expect(first.commands.isEmpty)

        coordinator.setReadiness(.eligible, id: firstID)
        coordinator.setReadiness(.eligible, id: secondID)
        await second.waitForCount(4)
        await coordinator.deliver(.navigate(.openProduct(2)))
        await second.waitForCount(5)
        #expect(first.commands.isEmpty)
        #expect(second.productIDs == [1, 1, 1, 1, 2])
    }

    @Test(.timeLimit(.minutes(1)))
    func reentrantDeliveryStaysFIFO() async {
        let coordinator = LocalNotificationNavigationCoordinator()
        let receiver = NotificationCommandReceiverSpy()
        receiver.onReceive = { command in
            guard command == .navigate(.openProduct(1)) else { return }
            await coordinator.deliver(.navigate(.openProduct(3)))
        }
        let id = UUID()
        coordinator.register(id: id, receiver: receiver)
        await coordinator.deliver(.navigate(.openProduct(1)))
        await coordinator.deliver(.navigate(.openProduct(2)))
        coordinator.setReadiness(.eligible, id: id)
        await receiver.waitForCount(3)

        #expect(receiver.productIDs == [1, 2, 3])
    }
}

private extension NotificationSceneReadiness {
    static let eligible = NotificationSceneReadiness(
        isRestored: true,
        isMain: true,
        isReady: true,
        isPlatformEligible: true
    )
}

@MainActor
private final class NotificationCommandReceiverSpy: LocalNotificationSceneReceiving {
    var commands: [NotificationNavigationCommand] = []
    var onReceive: ((NotificationNavigationCommand) async -> Void)?

    var productIDs: [Int] {
        commands.compactMap {
            guard case let .navigate(.openProduct(id)) = $0 else { return nil }
            return id
        }
    }

    func receiveNotificationCommand(_ command: NotificationNavigationCommand) async {
        commands.append(command)
        await onReceive?(command)
    }

    func waitForCount(_ count: Int) async {
        while commands.count < count { await Task.yield() }
    }
}

@MainActor
private final class QueueDiagnosticSpy {
    var values: [NotificationQueueDiagnostic] = []
    func record(_ value: NotificationQueueDiagnostic) { values.append(value) }
}
