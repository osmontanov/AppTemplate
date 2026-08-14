import Foundation

nonisolated enum NotificationResponseKind: Hashable, Sendable {
    case opened
    case action(LocalNotificationActionID)
}

nonisolated struct NotificationResponseReceipt: Hashable, Sendable {
    let requestID: LocalNotificationID
    let kind: NotificationResponseKind
    let deliveredAt: Date
}

nonisolated struct ManagedLocalNotificationResponse: Sendable {
    let event: LocalNotificationEvent
    let deliveredAt: Date
}
