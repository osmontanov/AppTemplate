import Foundation

nonisolated
protocol IAppNotificationCategoryCatalog: Sendable {
    func categories() async -> [LocalNotificationCategory]
    func bootstrapIfNeeded() async throws
    func replaceLabCategories(_ categories: [LocalNotificationCategory]) async throws
    func resetLabCategories() async throws
}
