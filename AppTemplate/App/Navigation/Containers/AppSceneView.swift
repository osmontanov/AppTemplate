import OSLog
import SwiftUI

struct AppSceneView: View {
    let appFlowCoordinator: AppFlowCoordinator
    let session: SessionPresentation
    let localNotifications: LocalNotificationDependencies
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport
    private let navigationPersistencePolicy:
        AppSceneNavigationPersistencePolicy

    @State private var lifecycle: AppSceneNavigationLifecycle
    @State private var protectedStoreActionExecutor: ProtectedStoreActionExecutor
    @State private var notificationCommandReceiver: AppSceneNotificationCommandReceiver
    @State private var onboardingRouter: FlowRouter
    @State private var maintenanceRouter: FlowRouter
    @State private var localNotificationRegistration:
        LocalNotificationSceneRegistration
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
        navigationPersistencePolicy:
            AppSceneNavigationPersistencePolicy = .restored
    ) {
        self.appFlowCoordinator = appFlowCoordinator
        self.session = session
        self.localNotifications = localNotifications
        self.storeDependencies = storeDependencies
        self.storeUISupport = storeUISupport
        self.navigationPersistencePolicy = navigationPersistencePolicy
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
            session: session,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport
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
                if lifecycle.receive(url) != nil {
                    persist()
                }
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
    }

    private var rejectedLinkRecovery: some View {
        VStack(spacing: 8) {
            Text("That link could not be opened.")
                .font(.headline)
            HStack {
                Button("Open Store") {
                    lifecycle.recoverRejectedLink(.openStore)
                }
                .accessibilityIdentifier("action.deep-link.open-store")
                Button("Open Services") {
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
