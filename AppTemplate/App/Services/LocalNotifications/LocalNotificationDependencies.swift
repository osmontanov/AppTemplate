import Foundation

nonisolated
struct LocalNotificationDependencies: Sendable {
    let service: any ILocalNotificationService
    let categoryCatalog: any IAppNotificationCategoryCatalog
    let eventHub: LocalNotificationEventHub
    let eventHistory: LocalNotificationEventHistory
    let navigationCoordinator: LocalNotificationNavigationCoordinator

    private let delegateBridge: NotificationCenterDelegateBridge?

    init(
        service: any ILocalNotificationService,
        categoryCatalog: any IAppNotificationCategoryCatalog,
        eventHub: LocalNotificationEventHub,
        eventHistory: LocalNotificationEventHistory,
        navigationCoordinator: LocalNotificationNavigationCoordinator,
        delegateBridge: NotificationCenterDelegateBridge? = nil
    ) {
        self.service = service
        self.categoryCatalog = categoryCatalog
        self.eventHub = eventHub
        self.eventHistory = eventHistory
        self.navigationCoordinator = navigationCoordinator
        self.delegateBridge = delegateBridge
    }

    func bootstrapCategoriesIfNeeded() async throws {
        try await categoryCatalog.bootstrapIfNeeded()
    }
}

nonisolated extension LocalNotificationSettings {
    static let inMemoryDefault = LocalNotificationSettings(
        authorizationStatus: .notDetermined,
        alertSetting: .disabled,
        soundSetting: .disabled,
        badgeSetting: .disabled,
        notificationCenterSetting: .disabled,
        lockScreenSetting: .disabled,
        alertStyle: .none,
        previewSetting: .never
    )
}
