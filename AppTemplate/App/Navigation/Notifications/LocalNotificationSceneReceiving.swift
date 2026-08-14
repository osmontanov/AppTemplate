import Foundation

nonisolated enum NotificationNavigationCommand: Equatable, Sendable {
    case navigate(NavigationIntent)
    case protected(ProtectedStoreAction)
}

nonisolated enum NotificationQueueDiagnostic: Equatable, Sendable {
    case queueOverflow(droppedCount: Int)
}

nonisolated struct NotificationSceneReadiness: Equatable, Sendable {
    let isRestored: Bool
    let isMain: Bool
    let isReady: Bool
    let isPlatformEligible: Bool

    var isEligible: Bool {
        isRestored && isMain && isReady && isPlatformEligible
    }
}

@MainActor
protocol LocalNotificationSceneReceiving: AnyObject {
    func receiveNotificationCommand(_ command: NotificationNavigationCommand) async
}
