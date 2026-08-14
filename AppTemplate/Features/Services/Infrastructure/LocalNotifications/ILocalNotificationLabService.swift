import Foundation

nonisolated
protocol ILocalNotificationLabService: Sendable {
    func settings() async -> LocalNotificationSettings
    func requestAuthorization(
        _ options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool
    func replaceLabCategories(
        _ categories: [LocalNotificationCategory]
    ) async throws
    func resetLabCategories() async throws
    func scheduleLab(_ request: LocalNotificationRequest) async throws
    func pendingLab() async -> [LocalNotificationPendingSnapshot]
    func deliveredLab() async -> [LocalNotificationDeliveredSnapshot]
    func removeLabPending(_ ids: Set<LocalNotificationID>) async
    func removeLabDelivered(_ ids: Set<LocalNotificationID>) async
    func resetLabData() async throws
}
