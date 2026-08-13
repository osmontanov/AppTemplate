import Foundation

nonisolated
struct LocalNotificationDependencies: Sendable {
    let service: any ILocalNotificationService
    let eventHub: LocalNotificationEventHub
    let navigationCoordinator: LocalNotificationNavigationCoordinator

    private let delegateBridge: NotificationCenterDelegateBridge?
    private let bootstrap: @Sendable () async throws -> Void

    init(
        service: any ILocalNotificationService,
        eventHub: LocalNotificationEventHub,
        navigationCoordinator: LocalNotificationNavigationCoordinator,
        bootstrap: @escaping @Sendable () async throws -> Void
    ) {
        self.service = service
        self.eventHub = eventHub
        self.navigationCoordinator = navigationCoordinator
        delegateBridge = nil
        self.bootstrap = bootstrap
    }

    private init(
        service: any ILocalNotificationService,
        eventHub: LocalNotificationEventHub,
        navigationCoordinator: LocalNotificationNavigationCoordinator,
        delegateBridge: NotificationCenterDelegateBridge,
        bootstrap: @escaping @Sendable () async throws -> Void
    ) {
        self.service = service
        self.eventHub = eventHub
        self.navigationCoordinator = navigationCoordinator
        self.delegateBridge = delegateBridge
        self.bootstrap = bootstrap
    }

    func bootstrapCategoriesIfNeeded() async throws {
        try await bootstrap()
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
        return LocalNotificationDependencies(
            service: service,
            eventHub: eventHub,
            navigationCoordinator: navigationCoordinator,
            delegateBridge: delegateBridge,
            bootstrap: { try await service.bootstrapCategoriesIfNeeded() }
        )
    }

    @MainActor
    static func inMemory(
        settings: LocalNotificationSettings = .inMemoryDefault,
        authorizationResult: Bool = true,
        categories: [LocalNotificationCategory] = []
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
            categories: categories,
            deepLinkPolicy: deepLinkPolicy(parser: parser),
            eventHub: eventHub
        )
        return LocalNotificationDependencies(
            service: service,
            eventHub: eventHub,
            navigationCoordinator: navigationCoordinator,
            bootstrap: {}
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
