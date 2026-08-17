import OSLog
import SwiftUI

nonisolated enum UITestDeepLinkHarnessAction: CaseIterable, Hashable, Sendable {
    case product
    case favorites

    var accessibilityIdentifier: String {
        switch self {
        case .product: "ui-test.action.open-product-link"
        case .favorites: "ui-test.action.open-favorites-link"
        }
    }

    var url: URL {
        switch self {
        case .product: URL(string: "apptemplate://store/product/1")!
        case .favorites: URL(string: "apptemplate://store/favorites")!
        }
    }
}

nonisolated extension UITestScenario.Name {
    var deepLinkHarnessAction: UITestDeepLinkHarnessAction? {
        switch self {
        case .guestStore: .product
        case .protectedFavorite: .favorites
        case .productReminder, .servicesBasic, .accessibilitySmoke: nil
        }
    }
}

struct AppSceneView: View {
    let appFlowCoordinator: AppFlowCoordinator
    let session: SessionPresentation
    let localNotifications: LocalNotificationDependencies
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport
    let servicesDependencies: ServicesDependencies
    private let navigationPersistencePolicy:
        AppSceneNavigationPersistencePolicy
    private let presentationOverrides: UITestPresentationOverrides?
    private let uiTestDeepLinkHarnessAction: UITestDeepLinkHarnessAction?

    @State private var lifecycle: AppSceneNavigationLifecycle
    @State private var storeCatalogViewModel: CatalogViewModel
    @State private var protectedStoreActionExecutor: ProtectedStoreActionExecutor
    @State private var notificationCommandReceiver: AppSceneNotificationCommandReceiver
    @State private var onboardingRouter: FlowRouter
    @State private var maintenanceRouter: FlowRouter
    @State private var localNotificationRegistration:
        LocalNotificationSceneRegistration
    @State private var showsUITestDeepLinkHarness = true
    @SceneStorage("AppTemplate.NavigationSnapshot") private var encodedSnapshot: Data?

    #if os(iOS)
    @Environment(\.scenePhase) private var scenePhase
    #endif

    private var appFlowRouter: AppFlowRouter {
        appFlowCoordinator.appFlowRouter
    }

    init(
        appFlowCoordinator: AppFlowCoordinator,
        session: SessionPresentation,
        localNotifications: LocalNotificationDependencies,
        storeDependencies: StoreDependencies,
        storeUISupport: StoreUISupport,
        servicesDependencies: ServicesDependencies,
        navigationPersistencePolicy:
            AppSceneNavigationPersistencePolicy = .restored,
        presentationOverrides: UITestPresentationOverrides? = nil,
        uiTestDeepLinkHarnessAction: UITestDeepLinkHarnessAction? = nil
    ) {
        self.appFlowCoordinator = appFlowCoordinator
        self.session = session
        self.localNotifications = localNotifications
        self.storeDependencies = storeDependencies
        self.storeUISupport = storeUISupport
        self.servicesDependencies = servicesDependencies
        self.navigationPersistencePolicy = navigationPersistencePolicy
        self.presentationOverrides = presentationOverrides
        self.uiTestDeepLinkHarnessAction = uiTestDeepLinkHarnessAction
        let sceneStoreRouter = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowCoordinator.appFlowRouter
        )
        let executor = ProtectedStoreActionExecutor(
            router: sceneStoreRouter.router.store,
            products: storeDependencies.products,
            favorites: storeDependencies.favorites,
            session: storeDependencies.session
        )
        _lifecycle = State(initialValue: sceneStoreRouter)
        _storeCatalogViewModel = State(initialValue: CatalogViewModel(
            products: storeDependencies.products,
            preferences: storeDependencies.preferences,
            clock: storeUISupport.clock
        ))
        _protectedStoreActionExecutor = State(initialValue: executor)
        _notificationCommandReceiver = State(initialValue: AppSceneNotificationCommandReceiver(
            navigation: sceneStoreRouter,
            router: sceneStoreRouter.router.store,
            executor: executor,
            session: storeDependencies.session
        ))
        _onboardingRouter = State(
            initialValue: FlowRouter(appFlowCoordinator: appFlowCoordinator)
        )
        _maintenanceRouter = State(
            initialValue: FlowRouter(appFlowCoordinator: appFlowCoordinator)
        )
        _localNotificationRegistration = State(
            initialValue: LocalNotificationSceneRegistration(
                coordinator: localNotifications.navigationCoordinator
            )
        )
    }

    var body: some View {
        AppRootView(
            appFlowRouter: appFlowRouter,
            router: lifecycle.router,
            onboardingRouter: onboardingRouter,
            maintenanceRouter: maintenanceRouter,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport,
            storeCatalogViewModel: storeCatalogViewModel,
            servicesDependencies: servicesDependencies,
            sceneNavigation: lifecycle
        )
            .environment(protectedStoreActionExecutor)
            .task {
                let restorationData = navigationPersistencePolicy.restorationData(
                    from: encodedSnapshot
                )
                let shouldPersistRestoration = lifecycle.restore(
                    from: restorationData,
                    applying: appFlowRouter.transition
                ) != nil
                protectedStoreActionExecutor.sessionDidChange(session)
                execute(lifecycle.reconcile(session), presentation: session)
                localNotificationRegistration.setNavigationState(
                    isRestored: lifecycle.hasRestored,
                    isMain: appFlowRouter.flow == .main,
                    isReady: lifecycle.isNavigationReady
                )
                if shouldPersistRestoration || lifecycle.isNavigationReady {
                    persist()
                }
            }
            .onChange(of: session) { _, presentation in
                guard lifecycle.hasRestored else { return }
                protectedStoreActionExecutor.sessionDidChange(presentation)
                execute(
                    lifecycle.reconcile(presentation),
                    presentation: presentation
                )
                localNotificationRegistration.setNavigationState(
                    isRestored: lifecycle.hasRestored,
                    isMain: appFlowRouter.flow == .main,
                    isReady: lifecycle.isNavigationReady
                )
                persist()
            }
            .onChange(of: lifecycle.router.snapshot) { _, _ in
                guard lifecycle.hasRestored else {
                    return
                }
                persist()
            }
            .onChange(of: appFlowRouter.transition) { _, transition in
                guard lifecycle.hasRestored else {
                    return
                }
                _ = lifecycle.apply(transition)
                localNotificationRegistration.setNavigationState(
                    isRestored: lifecycle.hasRestored,
                    isMain: appFlowRouter.flow == .main,
                    isReady: lifecycle.isNavigationReady
                )
                persist()
            }
            .onOpenURL { url in
                receiveAndPersist(url)
            }
            .task {
                await localNotificationRegistration.run(
                    receiver: notificationCommandReceiver,
                    bootstrap: localNotifications.bootstrapCategoriesIfNeeded
                )
            }
            .overlay(alignment: .top) {
                if lifecycle.presentation().deepLinkFailure != nil {
                    rejectedLinkRecovery
                }
            }
            .overlay(alignment: .topLeading) {
                if let action = uiTestDeepLinkHarnessAction,
                   showsUITestDeepLinkHarness {
                    Button {
                        showsUITestDeepLinkHarness = false
                        receiveAndPersist(action.url)
                    } label: {
                        Rectangle()
                            .fill(.black.opacity(0.001))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppText.resource("UI test deep link"))
                    .accessibilityIdentifier(action.accessibilityIdentifier)
                }
            }
            #if os(iOS)
            .onChange(of: scenePhase, initial: true) { _, phase in
                localNotificationRegistration.setPlatformEligible(
                    LocalNotificationSceneEligibility.isEligible(phase)
                )
            }
            #elseif os(macOS)
            .background {
                LocalNotificationWindowActivityProbe { isKeyWindow in
                    localNotificationRegistration.setPlatformEligible(isKeyWindow)
                }
            }
            #endif
            .modifier(UITestPresentationOverridesModifier(
                overrides: presentationOverrides
            ))
    }

    private func receiveAndPersist(_ url: URL) {
        if lifecycle.receive(url) != nil {
            persist()
        }
    }

    private var rejectedLinkRecovery: some View {
        VStack(spacing: 8) {
            Text(AppText.resource("That link could not be opened."))
                .font(.headline)
            HStack {
                Button(AppText.resource("Open Store")) {
                    lifecycle.recoverRejectedLink(.openStore)
                }
                .accessibilityIdentifier("action.deep-link.open-store")
                Button(AppText.resource("Open Services")) {
                    lifecycle.recoverRejectedLink(.openServices)
                }
                .accessibilityIdentifier("action.deep-link.open-services")
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
        .accessibilityIdentifier("presentation.deep-link-failure")
    }

    private func persist() {
        guard navigationPersistencePolicy.allowsSnapshotPersistence,
              let snapshot = lifecycle.snapshotForPersistence
        else {
            return
        }
        do {
            guard let encoding = try NavigationSnapshotCodec.encodingIfChanged(
                snapshot,
                comparedTo: encodedSnapshot
            ) else {
                return
            }
            encodedSnapshot = encoding
        } catch {
            Logger.navigation.error(
                "Failed to encode navigation snapshot: \(String(describing: error), privacy: .public)"
            )
        }
    }

    private func execute(
        _ action: ProtectedStoreAction?,
        presentation: SessionPresentation
    ) {
        guard let action,
              case let .authenticated(profile, _) = presentation.state else {
            return
        }
        Task {
            await protectedStoreActionExecutor.execute(
                action,
                expectedUserID: profile.id
            )
        }
    }
}

private struct UITestPresentationOverridesModifier: ViewModifier {
    let overrides: UITestPresentationOverrides?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let overrides {
            content
                .dynamicTypeSize(overrides.contentSize.dynamicTypeSize)
                .environment(
                    \.layoutDirection,
                    overrides.layoutDirection.swiftUILayoutDirection
                )
                .environment(
                    \.locale,
                    overrides.locale.localeIdentifier.map(Locale.init(identifier:))
                        ?? Locale.current
                )
                .transaction { transaction in
                    if overrides.reduceMotion {
                        transaction.animation = nil
                    }
                }
        } else {
            content
        }
    }
}

nonisolated
enum LocalNotificationSceneEligibility {
    static func isEligible(_ scenePhase: ScenePhase) -> Bool {
        scenePhase == .active
    }
}

@MainActor
final class LocalNotificationSceneRegistration {
    private let id = UUID()
    private let coordinator: LocalNotificationNavigationCoordinator
    private var readiness = NotificationSceneReadiness(
        isRestored: false,
        isMain: false,
        isReady: false,
        isPlatformEligible: false
    )
    private var nextGeneration: UInt64 = 0
    private var activeGeneration: UInt64?
    private var readyGeneration: UInt64?

    init(coordinator: LocalNotificationNavigationCoordinator) {
        self.coordinator = coordinator
    }

    func setPlatformEligible(_ isEligible: Bool) {
        readiness = NotificationSceneReadiness(
            isRestored: readiness.isRestored,
            isMain: readiness.isMain,
            isReady: readiness.isReady,
            isPlatformEligible: isEligible
        )
        guard let activeGeneration,
              readyGeneration == activeGeneration else {
            return
        }
        coordinator.setReadiness(readiness, id: id)
    }

    func setNavigationState(
        isRestored: Bool,
        isMain: Bool,
        isReady: Bool
    ) {
        readiness = NotificationSceneReadiness(
            isRestored: isRestored,
            isMain: isMain,
            isReady: isReady,
            isPlatformEligible: readiness.isPlatformEligible
        )
        guard let activeGeneration,
              readyGeneration == activeGeneration else {
            return
        }
        coordinator.setReadiness(readiness, id: id)
    }

    func run(
        receiver: any LocalNotificationSceneReceiving,
        bootstrap: @escaping @Sendable () async throws -> Void
    ) async {
        precondition(
            nextGeneration < UInt64.max,
            "Local notification scene generation exhausted"
        )
        let generation = nextGeneration
        nextGeneration += 1
        activeGeneration = generation
        readyGeneration = nil
        coordinator.register(id: id, receiver: receiver)
        defer { cleanup(generation: generation) }
        let bootstrapTask = Task {
            do {
                try await bootstrap()
            } catch {
                // Category bootstrap is retried by each Store schedule and does
                // not gate an otherwise ready scene.
            }
        }
        defer { bootstrapTask.cancel() }

        guard !Task.isCancelled, activeGeneration == generation else { return }
        readyGeneration = generation
        coordinator.setReadiness(readiness, id: id)

        let lifetime = AsyncStream.makeStream(of: Void.self)
        defer { lifetime.continuation.finish() }
        for await _ in lifetime.stream {}
    }

    private func cleanup(generation: UInt64) {
        guard activeGeneration == generation else { return }
        activeGeneration = nil
        readyGeneration = nil
        coordinator.unregister(id: id)
    }
}
