import Foundation

nonisolated
struct LocalNotificationDependencies: Sendable {
    let service: any ILocalNotificationService
    let categoryCatalog: any IAppNotificationCategoryCatalog
    let eventHub: LocalNotificationEventHub
    let navigationCoordinator: LocalNotificationNavigationCoordinator

    private let delegateBridge: NotificationCenterDelegateBridge?

    init(
        service: any ILocalNotificationService,
        eventHub: LocalNotificationEventHub,
        navigationCoordinator: LocalNotificationNavigationCoordinator,
        categoryCatalog: any IAppNotificationCategoryCatalog
    ) {
        self.service = service
        self.categoryCatalog = categoryCatalog
        self.eventHub = eventHub
        self.navigationCoordinator = navigationCoordinator
        delegateBridge = nil
    }

    private init(
        service: any ILocalNotificationService,
        eventHub: LocalNotificationEventHub,
        navigationCoordinator: LocalNotificationNavigationCoordinator,
        delegateBridge: NotificationCenterDelegateBridge,
        categoryCatalog: any IAppNotificationCategoryCatalog
    ) {
        self.service = service
        self.categoryCatalog = categoryCatalog
        self.eventHub = eventHub
        self.navigationCoordinator = navigationCoordinator
        self.delegateBridge = delegateBridge
    }

    func bootstrapCategoriesIfNeeded() async throws {
        try await categoryCatalog.bootstrapIfNeeded()
    }

    @MainActor
    static func live(
        runtimeResolver: @MainActor () -> UserNotificationCenterRuntime =
            UserNotificationCenterRuntimeFactory.live
    ) -> LocalNotificationDependencies {
        let runtime = runtimeResolver()
        let namespace = try! LocalNotificationNamespace()
        let parser = DeepLinkParser()
        let deepLinkPolicy = Self.deepLinkPolicy(parser: parser)
        let eventHub = LocalNotificationEventHub()
        let navigationCoordinator = LocalNotificationNavigationCoordinator(
            eventHub: eventHub,
            parser: parser
        )
        navigationCoordinator.start()
        let delegateBridge = NotificationCenterDelegateBridge(
            namespace: namespace,
            deepLinkPolicy: deepLinkPolicy,
            eventHub: eventHub,
            unmanagedHandler: nil
        )
        runtime.installDelegate(delegateBridge)
        let service = LocalNotificationService(
            namespace: namespace,
            validator: .live,
            deepLinkPolicy: deepLinkPolicy,
            envelopeCodec: .live,
            stager: .live,
            eventHub: eventHub,
            startupCategories: [],
            client: runtime.client
        )
        let categoryCatalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: StoreProductNotificationCategory.make(),
            gate: AsyncOperationGate()
        )
        return LocalNotificationDependencies(
            service: service,
            eventHub: eventHub,
            navigationCoordinator: navigationCoordinator,
            delegateBridge: delegateBridge,
            categoryCatalog: categoryCatalog
        )
    }

    @MainActor
    static func inMemory(
        settings: LocalNotificationSettings = .inMemoryDefault,
        authorizationResult: Bool = true
    ) -> LocalNotificationDependencies {
        let parser = DeepLinkParser()
        let eventHub = LocalNotificationEventHub()
        let navigationCoordinator = LocalNotificationNavigationCoordinator(
            eventHub: eventHub,
            parser: parser
        )
        navigationCoordinator.start()
        let service = InMemoryLocalNotificationService(
            settings: settings,
            authorizationResult: authorizationResult,
            deepLinkPolicy: deepLinkPolicy(parser: parser),
            eventHub: eventHub
        )
        let categoryCatalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: StoreProductNotificationCategory.make(),
            gate: AsyncOperationGate()
        )
        return LocalNotificationDependencies(
            service: service,
            eventHub: eventHub,
            navigationCoordinator: navigationCoordinator,
            categoryCatalog: categoryCatalog
        )
    }

    private static func deepLinkPolicy(
        parser: DeepLinkParser
    ) -> LocalNotificationDeepLinkPolicy {
        LocalNotificationDeepLinkPolicy { url in
            if case .success = parser.parse(url) {
                return true
            }
            return false
        }
    }
}

private nonisolated extension LocalNotificationSettings {
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
