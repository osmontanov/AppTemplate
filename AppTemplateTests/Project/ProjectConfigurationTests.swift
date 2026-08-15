import CryptoKit
import Foundation
import SwiftUI
import Testing
@testable import AppTemplate

struct ProjectConfigurationTests {
    @MainActor
    @Test
    func navigationRootCanBeConstructed() async throws {
        let fixedInstant = ContinuousClock().now
        let fixedClock = AppClock(
            now: { Date(timeIntervalSince1970: 2_000_000_000) },
            monotonicNow: { fixedInstant },
            sleep: { _ in }
        )
        let remote = ProjectRemoteService()
        let imageLoader = ProjectImageLoader()
        let appInfo = AppInfoService(displayName: "AppTemplate", version: "1.0")
        let live = AppDependencies.live(
            localDatabaseService: LocalDatabaseService(configuration: .inMemory()),
            userDefaultsService: InMemoryUserDefaultsService(namespace: "Project.Live"),
            keychainService: InMemoryKeychainService(),
            servicesLabUserDefaultsService: InMemoryUserDefaultsService(
                namespace: "Project.Live.Services"
            ),
            servicesLabKeychainService: InMemoryKeychainService(),
            remoteService: remote,
            appInfoService: appInfo,
            imageLoader: imageLoader,
            clock: fixedClock,
            sessionStartupValidationPolicy: .disabled,
            sessionRefreshSchedulePolicy: .disabled,
            notificationGraph: .inMemory(imageLoader: imageLoader, clock: fixedClock)
        )
        let preview = AppDependencies.preview(
            appInfo: appInfo,
            remoteService: remote,
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: imageLoader,
            notificationGraph: .inMemory(imageLoader: imageLoader, clock: fixedClock)
        )
        let unitTest = AppDependencies.test(
            localDatabaseService: LocalDatabaseService(configuration: .inMemory()),
            remoteService: remote,
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: imageLoader,
            appStateStorage: InMemoryAppStateStorage(),
            keychainService: InMemoryKeychainService(),
            appInfo: appInfo,
            notificationGraph: .inMemory(imageLoader: imageLoader, clock: fixedClock)
        )
        let uiTest = AppDependencies.uiTesting(
            initialState: AppState(
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            ),
            remoteService: remote,
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: imageLoader,
            notificationGraph: .inMemory(imageLoader: imageLoader, clock: fixedClock)
        )
        let scriptedUITest = AppDependencies.uiTesting(
            scenario: try UITestScenario.named("services-basic")
        )

        for graph in [live, preview, unitTest, uiTest, scriptedUITest] {
            #expect(graph.localDatabase is LocalDatabaseService)
            #expect(graph.notificationGraph.dependencies.service is InMemoryLocalNotificationService)
        }
        #expect(live.sessionStartupValidationPolicy == .disabled)
        #expect(live.sessionRefreshSchedulePolicy == .disabled)

        let appFlowCoordinator = makeTestAppFlowCoordinator(
            visibleFlow: .main
        )
        let appFlowRouter = appFlowCoordinator.appFlowRouter
        let router = AppRouter(
            appFlowRouter: appFlowRouter
        )
        let onboardingRouter = FlowRouter(appFlowCoordinator: appFlowCoordinator)
        let maintenanceRouter = FlowRouter(appFlowCoordinator: appFlowCoordinator)
        let projectSession = ProjectSessionActions()
        let session = projectSession.presentation
        let storeDependencies = preview.makeStoreDependencies(session: projectSession)
        let storeUISupport = preview.storeUISupport
        let storeCatalogViewModel = CatalogViewModel(
            products: storeDependencies.products,
            preferences: storeDependencies.preferences,
            clock: storeUISupport.clock
        )
        let appStateInspector = AppStateInspector(
            store: AppStateStore(storage: InMemoryAppStateStorage()),
            router: appFlowRouter
        )
        let servicesDependencies = preview.makeServicesDependencies(
            appState: appStateInspector,
            appFlowCoordinator: appFlowCoordinator,
            sessionActions: projectSession,
            appStateStatus: ServicesAppStateStatus()
        )
        let sceneNavigation = AppSceneNavigationLifecycle(router: router)

        _ = ContentView(
            appFlowCoordinator: appFlowCoordinator,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport,
            servicesDependencies: servicesDependencies
        )
        _ = AppSceneView(
            appFlowCoordinator: appFlowCoordinator,
            session: session,
            localNotifications: preview.localNotifications,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport,
            servicesDependencies: servicesDependencies
        )
        _ = AppRootView(
            appFlowRouter: appFlowRouter,
            router: router,
            onboardingRouter: onboardingRouter,
            maintenanceRouter: maintenanceRouter,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport,
            storeCatalogViewModel: storeCatalogViewModel,
            servicesDependencies: servicesDependencies,
            sceneNavigation: sceneNavigation
        )
        _ = AppShellView(
            router: router,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport,
            storeCatalogViewModel: storeCatalogViewModel,
            servicesDependencies: servicesDependencies,
            sceneNavigation: sceneNavigation
        )
        _ = AppSectionContentView(
            section: .services,
            storeRouter: router.store,
            servicesRouter: router.services,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport,
            storeCatalogViewModel: storeCatalogViewModel,
            servicesDependencies: servicesDependencies,
            sceneNavigation: sceneNavigation
        )
        #if os(macOS)
        _ = MacSidebarAppShellView(
            router: router,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport,
            storeCatalogViewModel: storeCatalogViewModel,
            servicesDependencies: servicesDependencies,
            sceneNavigation: sceneNavigation
        )
        #else
        _ = AdaptiveTabAppShellView(
            router: router,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport,
            storeCatalogViewModel: storeCatalogViewModel,
            servicesDependencies: servicesDependencies,
            sceneNavigation: sceneNavigation
        )
        #endif
        _ = StoreFlowView(
            router: router.store,
            dependencies: storeDependencies,
            uiSupport: storeUISupport,
            catalogViewModel: storeCatalogViewModel
        )
        _ = ServicesFlowView(
            router: router.services,
            dependencies: servicesDependencies,
            sceneNavigation: sceneNavigation
        )
        let authenticationDependencies = AuthenticationDependencies(
            session: projectSession,
            cancellation: ProjectAuthenticationCancellation()
        )
        _ = AuthenticationView(dependencies: authenticationDependencies)
        _ = AuthenticationFlowView(dependencies: authenticationDependencies)
        _ = AuthenticationHelpView()
        _ = OnboardingFlowView(router: onboardingRouter)
        _ = OnboardingView(router: onboardingRouter)
        _ = ProfileView(
            router: router.store,
            session: projectSession,
            appInfo: preview.appInfo,
            preferences: preview.storePreferences
        )
        _ = StoreSettingsSceneView(dependencies: storeDependencies)
        _ = CheckoutFlowView(
            cart: CartAggregate(id: CartAggregate.singletonID, revision: 0, lines: []),
            repository: preview.cart,
            onDone: {},
            onRevisionConflict: {}
        )
        _ = MaintenanceFlowView(router: maintenanceRouter)
        _ = MaintenanceView(router: maintenanceRouter)

        #expect(await remote.callCount == 0)
        #expect(imageLoader.loadCount == 0)
    }
}

@MainActor
private final class ProjectAuthenticationCancellation:
    IAuthenticationCancellation
{
    func cancelAuthentication() {}
}

@MainActor
private final class ProjectSessionActions: ISessionActions {
    private(set) var status = SessionStatusPresentation(
        session: SessionPresentation(state: .guest, revision: 1),
        expiry: nil
    )
    var presentation: SessionPresentation { status.session }

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
    func signOut() async -> SessionSignOutResult { .cancelled }
}

extension ProjectConfigurationTests {
    @Test
    func applicationRegistersCustomURLScheme() throws {
        let urlTypes = try #require(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes")
                as? [[String: Any]]
        )
        let schemes = urlTypes
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .flatMap { $0 }

        #expect(schemes.contains("apptemplate"))
    }

    @Test
    func releaseGateFreezesCriticalRowsAndUsesPerRunVerifierHelpers() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let predeleteData = try Data(contentsOf: projectRoot.appending(
            path: "Scripts/connected-mini-store-required-unit-tests-predelete.tsv"
        ))
        let finalData = try Data(contentsOf: projectRoot.appending(
            path: "Scripts/connected-mini-store-required-unit-tests-final.tsv"
        ))
        let uiData = try Data(contentsOf: projectRoot.appending(
            path: "Scripts/connected-mini-store-required-ui-tests.tsv"
        ))
        let finalManifestData = try Data(contentsOf: projectRoot.appending(
            path: "Scripts/connected-mini-store-final-change-paths.txt"
        ))
        let scriptData = try Data(contentsOf: projectRoot.appending(
            path: "Scripts/verify-connected-mini-store-release.zsh"
        ))
        let script = try #require(String(data: scriptData, encoding: .utf8))
        let predeleteHash = SHA256.hash(data: predeleteData).map {
            String(format: "%02x", $0)
        }.joined()
        let finalHash = SHA256.hash(data: finalData).map {
            String(format: "%02x", $0)
        }.joined()
        let uiHash = SHA256.hash(data: uiData).map {
            String(format: "%02x", $0)
        }.joined()
        let finalManifestHash = SHA256.hash(data: finalManifestData).map {
            String(format: "%02x", $0)
        }.joined()

        #expect(predeleteHash == "24a58469b053431beff914adc227605d50c9d5227c57e0a175938699b38b306f")
        #expect(finalHash == "9c2ed088e0f39eac824c1a34e79f41013f7cdb0f5f617a938eb5ff076b483709")
        #expect(uiHash == "263d944b6275632c909cfa48ea823907dcd8f08a74475c148717a5f87863d375")
        #expect(finalManifestHash == "ded52afd2152598f2b20bf7fba5b125758c760ed41bb2b31abd039a32d13b4a4")
        #expect(predeleteData.split(separator: 0x0a).count == 34)
        #expect(finalData.split(separator: 0x0a).count == 35)
        #expect(finalManifestData.split(separator: 0x0a).count == 227)
        let projectGateRow = Data(
            "all\tProjectConfigurationTests/releaseGateFreezesCriticalRowsAndUsesPerRunVerifierHelpers()\n".utf8
        )
        #expect(predeleteData.range(of: projectGateRow) != nil)
        #expect(finalData.range(of: projectGateRow) != nil)
        let attachmentGateRow = Data(
            "all\tLocalNotificationAttachmentStagerTests/absoluteRootAndSourceUseSingleAtomicNoFollowAnyOpens()\n".utf8
        )
        #expect(predeleteData.range(of: attachmentGateRow) != nil)
        #expect(finalData.range(of: attachmentGateRow) != nil)
        let trustedReminderRootRow = Data(
            "all\tAppNotificationGraphTests/liveReminderAttachmentDirectoryCanonicalizesTheTrustedTemporaryRoot()\n".utf8
        )
        #expect(predeleteData.range(of: trustedReminderRootRow) != nil)
        #expect(finalData.range(of: trustedReminderRootRow) != nil)
        let sharedLocalizationFallbackRow = Data(
            "all\tStoreServicesLocalizationTests/missingArabicSharedKeysUseTheirEnglishVisibleCopyInsteadOfTheSymbolicKey()\n".utf8
        )
        #expect(predeleteData.range(of: sharedLocalizationFallbackRow) != nil)
        #expect(finalData.range(of: sharedLocalizationFallbackRow) != nil)
        let productAttachmentFallbackRow = Data(
            "all\tProductReminderRepositoryTests/systemRejectedOwnedAttachmentRetriesTextOnlyWithWarning()\n".utf8
        )
        #expect(predeleteData.range(of: productAttachmentFallbackRow) != nil)
        #expect(finalData.range(of: productAttachmentFallbackRow) != nil)
        let delegateMainThreadRow = Data(
            "all\tNotificationCenterDelegateBridgeTests/frameworkCompletionsReturnToMainThreadAfterOffMainProcessing()\n".utf8
        )
        #expect(predeleteData.range(of: delegateMainThreadRow) != nil)
        #expect(finalData.range(of: delegateMainThreadRow) != nil)
        #expect(script.contains("predelete_required_hash=\"$(shasum -a 256 \"$predelete_required\")\""))
        #expect(script.contains("final_required_hash=\"$(shasum -a 256 \"$final_required\")\""))
        #expect(script.contains("ui_required_hash=\"$(shasum -a 256 \"$ui_required\")\""))
        #expect(script.contains("final_manifest_hash=\"$(shasum -a 256 \"$final_manifest\")\""))
        #expect(script.contains("== 227 ]] || exit 66"))
        #expect(script.contains("== 33 ]] || exit 66"))
        #expect(script.contains("== 34 ]] || exit 66"))
        #expect(script.contains("ded52afd2152598f2b20bf7fba5b125758c760ed41bb2b31abd039a32d13b4a4"))
        #expect(script.contains("24a58469b053431beff914adc227605d50c9d5227c57e0a175938699b38b306f"))
        #expect(script.contains("9c2ed088e0f39eac824c1a34e79f41013f7cdb0f5f617a938eb5ff076b483709"))
        #expect(script.contains("AppTemplate-XCResultRequiredTestsVerifier.XXXXXX"))
        #expect(script.contains("INFOPLIST_KEY_XCResultVerifierRoot=\"$helper_run_root\""))
        #expect(script.contains("rmdir \"$helper_run_root\""))
        #expect(!script.contains("mv -f \"$verifier_stage/verifier\""))
        #expect(script.contains("release_lock=\"/private/var/tmp/AppTemplate-connected-mini-store-release.$release_account_uid.$release_bundle_id.lock\""))
        #expect(script.contains("exec {release_lock_fd}>> \"$release_lock\""))
        #expect(script.contains("/usr/bin/lockf -s -t 0 \"$release_lock_fd\""))
        #expect(!script.contains("trap release_lock_cleanup EXIT HUP INT TERM"))
        #expect(script.contains("XCRESULT_REQUIRED_TESTS_RUNNER is reserved for verifier fixture tests"))
        #expect(script.contains("env -u XCRESULT_REQUIRED_TESTS_RUNNER swift Scripts/verify-xcresult-required-tests.swift"))
        #expect(script.contains("mkdir \"$app_container\""))
        #expect(script.contains("mkdir \"$container_data\""))
        #expect(script.contains("mkdir \"$container_tmp\""))
    }
}

private actor ProjectRemoteService: IRemoteService {
    private(set) var callCount = 0

    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO {
        callCount += 1
        throw ProjectConfigurationFailure.unexpectedExternalCall
    }

    func categories() async throws -> [ProductCategoryDTO] {
        callCount += 1
        throw ProjectConfigurationFailure.unexpectedExternalCall
    }

    func product(id: Int) async throws -> ProductDTO {
        callCount += 1
        throw ProjectConfigurationFailure.unexpectedExternalCall
    }

    func login(_ request: LoginRequestDTO) async throws -> AuthSessionDTO {
        callCount += 1
        throw ProjectConfigurationFailure.unexpectedExternalCall
    }

    func me(accessToken: String) async throws -> UserProfileDTO {
        callCount += 1
        throw ProjectConfigurationFailure.unexpectedExternalCall
    }

    func refresh(_ request: RefreshRequestDTO) async throws -> AuthTokensDTO {
        callCount += 1
        throw ProjectConfigurationFailure.unexpectedExternalCall
    }

    func diagnostic(
        _ request: HTTPDiagnosticRequest
    ) async throws -> HTTPDiagnosticDTO {
        callCount += 1
        throw ProjectConfigurationFailure.unexpectedExternalCall
    }
}

private final class ProjectImageLoader: IImageLoader, @unchecked Sendable {
    private let lock = NSLock()
    private var storedLoadCount = 0

    var loadCount: Int { lock.withLock { storedLoadCount } }

    func load(_ url: URL, policy: ImageLoadPolicy) async throws -> LoadedImage {
        lock.withLock { storedLoadCount += 1 }
        throw ProjectConfigurationFailure.unexpectedExternalCall
    }
}

private enum ProjectConfigurationFailure: Error {
    case unexpectedExternalCall
}
