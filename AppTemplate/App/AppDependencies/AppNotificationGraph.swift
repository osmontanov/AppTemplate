import Foundation

nonisolated
struct AppNotificationGraph: Sendable {
    let dependencies: LocalNotificationDependencies
    let reminders: any IProductReminderRepository

    @MainActor
    static func live(
        imageLoader: any IImageLoader,
        clock: AppClock,
        runtimeResolver: @MainActor () -> UserNotificationCenterRuntime =
            UserNotificationCenterRuntimeFactory.live
    ) -> AppNotificationGraph {
        let runtime = runtimeResolver()
        let namespace = try! LocalNotificationNamespace()
        let parser = DeepLinkParser()
        let deepLinkPolicy = makeDeepLinkPolicy(parser: parser)
        let history = LocalNotificationEventHistory(clock: clock)
        let eventHub = LocalNotificationEventHub(history: history)
        let receipts = NotificationResponseReceiptStore()
        let coordinator = LocalNotificationNavigationCoordinator {
            guard case .queueOverflow = $0 else { return }
            await eventHub.publish(.diagnostic(.init(
                id: nil,
                reason: .notificationQueueOverflow
            )))
        }
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
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: StoreProductNotificationCategory.make(),
            gate: AsyncOperationGate()
        )
        let reminders = makeReminderRepository(
            service: service,
            catalog: catalog,
            imageLoader: imageLoader,
            clock: clock
        )
        let dispatcher = StoreNotificationActionDispatcher(
            coordinator: coordinator,
            reminders: reminders,
            receipts: receipts,
            diagnosticSink: { diagnostic in
                await eventHub.publish(.diagnostic(diagnostic))
            }
        )
        let bridge = NotificationCenterDelegateBridge(
            namespace: namespace,
            deepLinkPolicy: deepLinkPolicy,
            eventHub: eventHub,
            responseDispatcher: dispatcher,
            unmanagedHandler: nil
        )
        runtime.installDelegate(bridge)
        return AppNotificationGraph(
            dependencies: LocalNotificationDependencies(
                service: service,
                categoryCatalog: catalog,
                eventHub: eventHub,
                eventHistory: history,
                navigationCoordinator: coordinator,
                delegateBridge: bridge
            ),
            reminders: reminders
        )
    }

    @MainActor
    static func inMemory(
        settings: LocalNotificationSettings = .inMemoryDefault,
        authorizationResult: Bool = true,
        imageLoader: any IImageLoader = FailClosedImageLoader(),
        clock: AppClock = .live
    ) -> AppNotificationGraph {
        let namespace = try! LocalNotificationNamespace()
        let parser = DeepLinkParser()
        let deepLinkPolicy = makeDeepLinkPolicy(parser: parser)
        let history = LocalNotificationEventHistory(clock: clock)
        let eventHub = LocalNotificationEventHub(history: history)
        let receipts = NotificationResponseReceiptStore()
        let coordinator = LocalNotificationNavigationCoordinator {
            guard case .queueOverflow = $0 else { return }
            await eventHub.publish(.diagnostic(.init(
                id: nil,
                reason: .notificationQueueOverflow
            )))
        }
        let service = InMemoryLocalNotificationService(
            settings: settings,
            authorizationResult: authorizationResult,
            deepLinkPolicy: deepLinkPolicy,
            eventHub: eventHub
        )
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: StoreProductNotificationCategory.make(),
            gate: AsyncOperationGate()
        )
        let reminders = makeReminderRepository(
            service: service,
            catalog: catalog,
            imageLoader: imageLoader,
            clock: clock
        )
        let dispatcher = StoreNotificationActionDispatcher(
            coordinator: coordinator,
            reminders: reminders,
            receipts: receipts,
            diagnosticSink: { diagnostic in
                await eventHub.publish(.diagnostic(diagnostic))
            }
        )
        let bridge = NotificationCenterDelegateBridge(
            namespace: namespace,
            deepLinkPolicy: deepLinkPolicy,
            eventHub: eventHub,
            responseDispatcher: dispatcher,
            unmanagedHandler: nil
        )
        return AppNotificationGraph(
            dependencies: LocalNotificationDependencies(
                service: service,
                categoryCatalog: catalog,
                eventHub: eventHub,
                eventHistory: history,
                navigationCoordinator: coordinator,
                delegateBridge: bridge
            ),
            reminders: reminders
        )
    }

    private static func makeDeepLinkPolicy(
        parser: DeepLinkParser
    ) -> LocalNotificationDeepLinkPolicy {
        LocalNotificationDeepLinkPolicy { url in
            if case .success = parser.parse(url) { return true }
            return false
        }
    }

    private static func makeReminderRepository(
        service: any ILocalNotificationService,
        catalog: any IAppNotificationCategoryCatalog,
        imageLoader: any IImageLoader,
        clock: AppClock
    ) -> ProductReminderRepository {
        ProductReminderRepository(
            service: service,
            imageLoader: imageLoader,
            attachmentStager: ReminderAttachmentStager(
                directory: FileManager.default.temporaryDirectory
                    .appendingPathComponent(
                        "AppTemplate-ProductReminderAttachments",
                        isDirectory: true
                    )
            ),
            categoryCatalog: catalog,
            clock: clock
        )
    }
}
