import Foundation

nonisolated
protocol ILocalNotificationService: Sendable {
    func settings() async -> LocalNotificationSettings
    func requestAuthorization(_ options: LocalNotificationAuthorizationOptions) async throws -> Bool
    func setCategories(_ categories: [LocalNotificationCategory]) async throws
    func schedule(_ request: LocalNotificationRequest) async throws
    func pending() async -> [LocalNotificationPendingSnapshot]
    func delivered() async -> [LocalNotificationDeliveredSnapshot]
    func removePending(_ identifiers: Set<LocalNotificationID>) async
    func removeAllPending() async
    func removeDelivered(_ identifiers: Set<LocalNotificationID>) async
    func removeAllDelivered() async
    func setBadgeCount(_ count: Int) async throws
    func clearBadge() async throws
    func events() async -> AsyncStream<LocalNotificationEvent>
}
