import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct ServicesApplicationLabsTests {
    @Test
    func appInfoReadsInjectedValues() {
        let model = ServicesAppInfoViewModel(
            appInfo: AppInfoService(displayName: "Fixture", version: "7.2"),
            platformName: "Test Platform"
        )

        #expect((model.displayName, model.version, model.platformName)
            == ("Fixture", "7.2", "Test Platform"))
    }

    @Test
    func appStateInspectionUsesLiveStorePolicyAndRouterSources() {
        let storage = InMemoryAppStateStorage(initialState: AppState(
            schemaVersion: 2,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        ))
        let store = AppStateStore(storage: storage)
        let router = AppFlowRouter(flow: .main)
        let inspector = AppStateInspector(store: store, router: router)

        #expect(inspector.inspection == AppStateInspection(
            schemaVersion: 2,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false,
            persistenceStatus: .writable,
            root: .main
        ))

        _ = store.setState(AppState(
            schemaVersion: 2,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        ))
        router.setFlow(.maintenance)

        #expect(inspector.inspection == AppStateInspection(
            schemaVersion: 2,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true,
            persistenceStatus: .writable,
            root: .maintenance
        ))
    }

    @Test
    func projectionsStayLiveAndSessionStatusRemainsAtomic() {
        let appState = ServicesAppStateInspectorSpy()
        let coordinator = AppFlowCoordinatorSpy()
        let session = ServicesSessionActionsSpy()
        let status = ServicesAppStateStatus()
        let scene = ServicesSceneActionsSpy()
        let model = ServicesAppStateViewModel(
            appState: appState,
            appFlowCoordinator: coordinator,
            sessionActions: session,
            status: status,
            sceneNavigation: scene
        )
        let accessExpiry = Date(timeIntervalSince1970: 100)
        let refreshExpiry = Date(timeIntervalSince1970: 200)
        let nextSession = SessionStatusPresentation(
            session: SessionPresentation(state: .guest, revision: 19),
            expiry: SessionExpiryPresentation(
                accessExpiresAt: accessExpiry,
                refreshExpiresAt: refreshExpiry
            )
        )
        let nextScene = ServicesSceneActionsSpy.presentation(
            selectedSection: .services,
            servicesPath: [.appState, .appInfo]
        )

        appState.value = AppStateInspection(
            schemaVersion: 2,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true,
            persistenceStatus: .writable,
            root: .maintenance
        )
        session.status = nextSession
        scene.value = nextScene
        status.record(.success("Shared result."))

        #expect(model.application == appState.value)
        #expect(model.session == nextSession)
        #expect(model.scene == nextScene)
        #expect(model.lastResult == .success("Shared result."))
    }

    @Test
    func resetAndSampleIntentRouteOnlyToTheCurrentScene() {
        let fixture = ServicesTwoSceneFixture()

        fixture.first.resetNavigationInCurrentScene()
        fixture.first.handleSampleIntent(.openService(.appInfo))

        #expect(fixture.firstScene.resetCalls == 1)
        #expect(fixture.firstScene.intents == [.openService(.appInfo)])
        #expect(fixture.secondScene.resetCalls == 0)
        #expect(fixture.secondScene.intents.isEmpty)
        #expect(fixture.coordinator.commands.isEmpty)
        #expect(fixture.session.signOutCalls == 0)
    }

    @Test
    func appWideCommandsRouteOnceToTheirSemanticOwnersAcrossTwoScenes() async {
        let fixture = ServicesTwoSceneFixture()
        fixture.coordinator.restartOnboardingResult = .applied(
            flow: .onboarding,
            didTransition: true
        )
        fixture.coordinator.setMaintenanceEnabledResult = .applied(
            flow: .maintenance,
            didTransition: true
        )
        fixture.session.signOutResult = .guest

        fixture.first.restartOnboarding()
        fixture.second.setMaintenanceEnabled(true)
        await fixture.first.signOut()

        #expect(fixture.coordinator.commands == [
            .restartOnboarding,
            .setMaintenanceEnabled(true)
        ])
        #expect(fixture.session.signOutCalls == 1)
        #expect(fixture.firstScene.resetCalls == 0)
        #expect(fixture.secondScene.resetCalls == 0)
        #expect(fixture.firstScene.intents.isEmpty)
        #expect(fixture.secondScene.intents.isEmpty)
    }

    @Test(arguments: [
        (AppFlowActionResult.unchanged, ServiceLabResult.success("App state was already set.")),
        (.applied(flow: .main, didTransition: false), .success("App state updated.")),
        (.applied(flow: .onboarding, didTransition: true), .success("App flow updated.")),
        (.rejected(.loadFailed), .failure("App state could not be saved.")),
        (.rejected(.saveFailed), .failure("App state could not be saved.")),
        (.rejected(.encodingFailed), .failure("App state could not be saved.")),
        (.rejected(.migrationSaveFailed), .failure("App state could not be saved.")),
        (.rejected(.unsupportedFutureSchema(923)), .failure("App state could not be saved."))
    ])
    func appFlowResultsMapToBoundedSafeMessages(
        result: AppFlowActionResult,
        expected: ServiceLabResult
    ) {
        let fixture = ServicesTwoSceneFixture()
        fixture.coordinator.restartOnboardingResult = result

        fixture.first.restartOnboarding()

        #expect(fixture.first.lastResult == expected)
        #expect(!fixture.first.lastResult.message.contains("923"))
    }

    @Test(arguments: [
        (SessionSignOutResult.guest, ServiceLabResult.success("Signed out.")),
        (.deletionFailed, .failure("Sign out could not clear secure session data.")),
        (.cancelled, .failure("Sign out was cancelled."))
    ])
    func signOutResultsMapToBoundedSafeMessages(
        result: SessionSignOutResult,
        expected: ServiceLabResult
    ) async {
        let fixture = ServicesTwoSceneFixture()
        fixture.session.signOutResult = result

        await fixture.first.signOut()

        #expect(fixture.first.lastResult == expected)
    }

    @Test
    func signOutPublishesRunningBeforeTheFinalResult() async {
        let fixture = ServicesTwoSceneFixture()
        fixture.session.suspendSignOut = true
        fixture.session.signOutResult = .guest

        let operation = Task { await fixture.first.signOut() }
        while !fixture.session.hasStartedSignOut {
            await Task.yield()
        }

        #expect(fixture.first.lastResult == .running)
        fixture.session.resumeSignOut()
        await operation.value
        #expect(fixture.first.lastResult == .success("Signed out."))
    }

    @Test
    func sharedStatusSurvivesRootReplacementAndModelRecreation() {
        let storage = InMemoryAppStateStorage(initialState: AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        ))
        let store = AppStateStore(storage: storage)
        let router = AppFlowRouter(flow: .main)
        let coordinator = AppFlowCoordinator(
            store: store,
            appFlowRouter: router,
            isLocalSessionBootstrapResolved: true
        )
        let inspector = AppStateInspector(store: store, router: router)
        let session = ServicesSessionActionsSpy()
        let status = ServicesAppStateStatus()
        let first = ServicesAppStateViewModel(
            appState: inspector,
            appFlowCoordinator: coordinator,
            sessionActions: session,
            status: status,
            sceneNavigation: ServicesSceneActionsSpy()
        )

        first.restartOnboarding()
        let resultBeforeReplacement = first.lastResult
        let replacement = ServicesAppStateViewModel(
            appState: inspector,
            appFlowCoordinator: coordinator,
            sessionActions: session,
            status: status,
            sceneNavigation: ServicesSceneActionsSpy()
        )

        #expect(inspector.inspection.root == .onboarding)
        #expect(resultBeforeReplacement == .success("App flow updated."))
        #expect(replacement.lastResult == resultBeforeReplacement)
    }
}

private extension ServiceLabResult {
    var message: String {
        switch self {
        case .idle: ""
        case .running: ""
        case let .success(message): message
        case let .failure(message): message
        }
    }
}

@MainActor
private final class ServicesAppStateInspectorSpy: IAppStateInspecting {
    var value = AppStateInspection(
        schemaVersion: 2,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: false,
        persistenceStatus: .writable,
        root: .main
    )
    private(set) var readCount = 0

    var inspection: AppStateInspection {
        readCount += 1
        return value
    }
}

@MainActor
private final class ServicesSessionActionsSpy: ISessionActions {
    var status = SessionStatusPresentation(
        session: SessionPresentation(state: .guest, revision: 1),
        expiry: nil
    )
    var presentation: SessionPresentation { status.session }
    var signOutResult: SessionSignOutResult = .cancelled
    var suspendSignOut = false
    private(set) var signOutCalls = 0
    private(set) var hasStartedSignOut = false
    private var signOutContinuation: CheckedContinuation<Void, Never>?

    func bootstrap() async {}
    func retryBootstrap() async {}
    func login(username: String, password: String) async -> SessionLoginResult {
        _ = username
        _ = password
        return .cancelled
    }
    func retryPersistence(
        _ token: SessionPersistenceRetryToken
    ) async -> SessionPersistenceRetryResult {
        _ = token
        return .invalidToken
    }
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async {
        _ = token
    }
    func validateSession() async -> SessionValidationResult { .unchanged }
    func refreshSession() async -> SessionValidationResult { .unchanged }
    func signOut() async -> SessionSignOutResult {
        signOutCalls += 1
        hasStartedSignOut = true
        if suspendSignOut {
            await withCheckedContinuation { continuation in
                signOutContinuation = continuation
            }
        }
        return signOutResult
    }

    func resumeSignOut() {
        signOutContinuation?.resume()
        signOutContinuation = nil
    }
}

@MainActor
private final class ServicesSceneActionsSpy: ISceneNavigationActions {
    var value: SceneNavigationPresentation
    private(set) var resetCalls = 0
    private(set) var intents: [NavigationIntent] = []

    init(value: SceneNavigationPresentation = ServicesSceneActionsSpy.presentation()) {
        self.value = value
    }

    func presentation() -> SceneNavigationPresentation { value }

    func resetNavigationInCurrentScene() {
        resetCalls += 1
    }

    func handleSampleIntent(_ intent: NavigationIntent) {
        intents.append(intent)
    }

    func recoverRejectedLink(_ action: DeepLinkRecoveryAction) {
        _ = action
    }

    static func presentation(
        selectedSection: AppSection = .store,
        servicesPath: [ServicesRoute] = []
    ) -> SceneNavigationPresentation {
        SceneNavigationPresentation(
            selectedSection: selectedSection,
            storePath: [],
            servicesPath: servicesPath,
            restorationResult: .noState,
            checkpoint: nil,
            hasDeferredLink: false,
            hasPendingProtectedAction: false,
            deepLinkFailure: nil
        )
    }
}

@MainActor
private struct ServicesTwoSceneFixture {
    let coordinator = AppFlowCoordinatorSpy()
    let session = ServicesSessionActionsSpy()
    let status = ServicesAppStateStatus()
    let firstScene = ServicesSceneActionsSpy()
    let secondScene = ServicesSceneActionsSpy()
    let dependencies: ServicesDependencies
    let first: ServicesAppStateViewModel
    let second: ServicesAppStateViewModel

    init() {
        let appState = ServicesAppStateInspectorSpy()
        let notificationGraph = AppNotificationGraph.inMemory()
        let notificationFacade = LocalNotificationLabService(
            service: notificationGraph.dependencies.service,
            catalog: notificationGraph.dependencies.categoryCatalog,
            namespace: "services.lab"
        )
        dependencies = ServicesDependencies(
            appState: appState,
            appFlowCoordinator: coordinator,
            appStateStatus: status,
            sessionActions: session,
            appInfo: AppInfoService(displayName: "Fixture", version: "1"),
            userDefaultsLab: InMemoryUserDefaultsService(
                namespace: "AppTemplate.ServicesLab"
            ),
            keychainLab: InMemoryKeychainService(),
            localDatabase: LocalDatabaseExampleRepository(
                database: LocalDatabaseService(configuration: .inMemory())
            ),
            remoteAPI: RemoteAPILabService(remote: FailClosedRemoteService()),
            diagnostics: NetworkDiagnosticRecorder(),
            notificationLab: notificationFacade,
            notificationAppWide: notificationFacade,
            notificationHistory: notificationGraph.dependencies.eventReader,
            notificationAssets: LocalNotificationLabAssetProvider(
                resolve: { _ in nil },
                validate: { _ in .unreadable }
            )
        )
        first = ServicesAppStateViewModel(
            appState: dependencies.appState,
            appFlowCoordinator: dependencies.appFlowCoordinator,
            sessionActions: dependencies.sessionActions,
            status: dependencies.appStateStatus,
            sceneNavigation: firstScene
        )
        second = ServicesAppStateViewModel(
            appState: dependencies.appState,
            appFlowCoordinator: dependencies.appFlowCoordinator,
            sessionActions: dependencies.sessionActions,
            status: dependencies.appStateStatus,
            sceneNavigation: secondScene
        )
    }
}
