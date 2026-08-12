import Foundation

nonisolated
protocol LocalNotificationCenterClient: Sendable {
    func settings() async -> LocalNotificationSettings
    func requestAuthorization(_ options: LocalNotificationAuthorizationOptions) async throws -> Bool
    func replaceManagedCategories(
        prefix: String,
        categories: [LocalNotificationSystemCategory]
    ) async throws
    func add(_ request: LocalNotificationSystemRequest) async throws
    func pending() async -> [LocalNotificationSystemRequest]
    func delivered() async -> [LocalNotificationSystemDelivered]
    func removePending(_ physicalIDs: Set<String>) async
    func removeDelivered(_ physicalIDs: Set<String>) async
    func setBadgeCount(_ count: Int) async throws
}
