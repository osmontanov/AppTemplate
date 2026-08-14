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
        _lifecycle = State(
            initialValue: AppSceneNavigationLifecycle(
                appFlowRouter: appFlowCoordinator.appFlowRouter
            )
        )
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
            .task {
                let restorationData = navigationPersistencePolicy.restorationData(
                    from: encodedSnapshot
                )
                if lifecycle.restore(
                    from: restorationData,
                    applying: appFlowRouter.transition
                ) != nil {
                    persist()
                }
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
                persist()
            }
            .onOpenURL { url in
                if lifecycle.receive(url) != nil {
                    persist()
                }
            }
            .task {
                await localNotificationRegistration.run(
                    receiver: lifecycle,
                    bootstrap: localNotifications.bootstrapCategoriesIfNeeded
                )
            }
            #if os(iOS)
            .onChange(of: scenePhase, initial: true) { _, phase in
                localNotificationRegistration.setEligible(
                    LocalNotificationSceneEligibility.isEligible(phase)
                )
            }
            #elseif os(macOS)
            .background {
                LocalNotificationWindowActivityProbe { isKeyWindow in
                    localNotificationRegistration.setEligible(isKeyWindow)
                }
            }
            #endif
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
    private var currentEligibility = false
    private var nextGeneration: UInt64 = 0
    private var activeGeneration: UInt64?
    private var readyGeneration: UInt64?

    init(coordinator: LocalNotificationNavigationCoordinator) {
        self.coordinator = coordinator
    }

    func setEligible(_ isEligible: Bool) {
        currentEligibility = isEligible
        guard let activeGeneration,
              readyGeneration == activeGeneration else {
            return
        }
        coordinator.setEligible(isEligible, id: id)
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

        do {
            try await bootstrap()
        } catch {
            if error is CancellationError || Task.isCancelled {
                return
            }
        }

        guard !Task.isCancelled,
              activeGeneration == generation else {
            return
        }
        readyGeneration = generation
        coordinator.setEligible(currentEligibility, id: id)

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
