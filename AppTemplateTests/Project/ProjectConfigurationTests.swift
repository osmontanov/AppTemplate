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

        _ = PreviewAppCompositionView(
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
    func releaseGateFreezesRequiredManifestsThroughOneChecksumSource() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let checksumsPath = "Scripts/release-manifest-checksums.tsv"
        let checksums = try #require(String(
            data: try Data(contentsOf: projectRoot.appending(path: checksumsPath)),
            encoding: .utf8
        ))
        let script = try #require(String(
            data: try Data(contentsOf: projectRoot.appending(
                path: "Scripts/verify-release.zsh"
            )),
            encoding: .utf8
        ))

        var lines = checksums.components(separatedBy: "\n")
        #expect(lines.popLast() == "")
        #expect(lines.first == "sha256\tpath")
        var recordedManifests: Set<String> = []
        for line in lines.dropFirst() {
            let columns = line.components(separatedBy: "\t")
            #expect(columns.count == 2)
            guard columns.count == 2 else { continue }
            let manifestData = try Data(
                contentsOf: projectRoot.appending(path: columns[1])
            )
            let actual = SHA256.hash(data: manifestData).map {
                String(format: "%02x", $0)
            }.joined()
            #expect(
                actual == columns[0],
                "Stale checksum for \(columns[1]); run Scripts/update-release-manifest-checksums.zsh"
            )
            recordedManifests.insert(columns[1])
        }
        #expect(recordedManifests == [
            "Scripts/release-required-unit-tests.tsv",
            "Scripts/release-required-ui-tests.tsv"
        ])

        let unitRequired = try Data(contentsOf: projectRoot.appending(
            path: "Scripts/release-required-unit-tests.tsv"
        ))
        for identifier in Self.criticalRequiredUnitTests {
            #expect(
                unitRequired.range(of: Data("all\t\(identifier)\n".utf8)) != nil,
                "Release gate no longer requires \(identifier)"
            )
        }
        let uiRequired = try Data(contentsOf: projectRoot.appending(
            path: "Scripts/release-required-ui-tests.tsv"
        ))
        for row in Self.criticalRequiredUITests {
            #expect(
                uiRequired.range(of: Data("\(row)\n".utf8)) != nil,
                "Release gate no longer requires \(row)"
            )
        }

        // The hash check itself must stay in the script, or the checksum source
        // becomes decorative.
        #expect(script.contains("checksums=\"\(checksumsPath)\""))
        #expect(script.contains("manifest_hash=\"$(shasum -a 256 \"$manifest_path\")\""))
        #expect(script.contains("[[ \"${manifest_hash%% *}\" == \"$expected_hash\" ]] || exit 66"))
        #expect(script.contains("Scripts/update-release-manifest-checksums.zsh"))
        #expect(!script.contains("connected-mini-store"))
        // The hosted verifier suite looks its binaries up under this exact name
        // in the container's temporary directory; nothing else survives the
        // test-host launch, so the script and the suite must agree on it.
        #expect(script.contains(
            "helper_run_root=\"$container_tmp/AppTemplate-XCResultRequiredTestsVerifier\""
        ))
        #expect(script.contains("rmdir \"$helper_run_root\""))
        #expect(script.contains(
            "release_lock=\"/private/var/tmp/AppTemplate-release-gate.$release_account_uid.$release_bundle_id.lock\""
        ))
        #expect(script.contains("exec {release_lock_fd}>> \"$release_lock\""))
        #expect(script.contains("/usr/bin/lockf -s -t 0 \"$release_lock_fd\""))
        #expect(script.contains("XCRESULT_REQUIRED_TESTS_RUNNER is reserved for verifier fixture tests"))
        #expect(script.contains(
            "env -u XCRESULT_REQUIRED_TESTS_RUNNER swift Scripts/verify-xcresult-required-tests.swift"
        ))
        #expect(script.contains("SWIFT_TREAT_WARNINGS_AS_ERRORS=YES"))
        // Missing macOS UI automation is the one failure the gate may continue
        // past, and it has to announce the coverage it lost when it does.
        #expect(script.contains("Timed out while enabling automation mode"))
        #expect(script.contains("Release gate passed WITHOUT macOS UI coverage"))
        #expect(script.contains("exit 74"))
        #expect(script.contains("mkdir \"$app_container\""))
        #expect(script.contains("mkdir \"$container_data\""))
        #expect(script.contains("mkdir \"$container_tmp\""))
    }

    private static let criticalRequiredUnitTests = [
        "ProjectConfigurationTests/releaseGateFreezesRequiredManifestsThroughOneChecksumSource()",
        "LocalNotificationAttachmentStagerTests/absoluteRootAndSourceUseSingleAtomicNoFollowAnyOpens()",
        "AppNotificationGraphTests/liveReminderAttachmentDirectoryCanonicalizesTheTrustedTemporaryRoot()",
        "AppTextLocalizationTests/symbolicKeysAlwaysCarryTheirVisibleCopyAtTheCallSite()",
        "ProductReminderRepositoryTests/systemRejectedOwnedAttachmentRetriesTextOnlyWithWarning()",
        "NotificationCenterDelegateBridgeTests/frameworkCompletionsReturnToMainThreadAfterOffMainProcessing()"
    ]

    private static let criticalRequiredUITests = [
        "all\tStoreJourneyTests/testGuestCatalogReviewsCartCheckoutProfileAndPaths()",
        "all\tStoreJourneyTests/testProtectedFavoriteAuthenticationResumeAndSignOut()",
        "all\tAccessibilitySmokeTests/testArabicRTLKeepsLocalizedStoreReachable()",
        "iphone\tAccessibilitySmokeTests/testAdaptiveIOSLayoutSmoke()",
        "ipad\tAccessibilitySmokeTests/testAdaptiveIOSLayoutSmoke()",
        "macos\tAccessibilitySmokeTests/testMacOSKeyboardAndFocusSmoke()"
    ]
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
