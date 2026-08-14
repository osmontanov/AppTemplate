import Foundation

nonisolated
protocol ILocalNotificationAppWideCapabilities: Sendable {
    func pendingAppOwned() async -> [LocalNotificationPendingSnapshot]
    func deliveredAppOwned() async -> [LocalNotificationDeliveredSnapshot]
    func removeAllPending() async
    func removeAllDelivered() async
    func setBadgeCount(_ count: Int) async throws
    func clearBadge() async throws
}
