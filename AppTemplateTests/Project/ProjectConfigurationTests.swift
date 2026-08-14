import Foundation
import Observation
import SwiftUI
import Testing
@testable import AppTemplate

#if os(macOS)
import AppKit
#endif

struct ProjectConfigurationTests {
    @MainActor
    @Test
    func createProjectFlowKeepsItsNavigationPathIsolated() {
        let coordinator = makeTestAppFlowCoordinator()
        let presentingRouter = FlowRouter(
            appFlowCoordinator: coordinator
        )
        let flow = CreateProjectFlowView(
            appFlowCoordinator: presentingRouter
        )

        flow.localRouter.push(ProjectBasicsRoute.options)

        #expect(flow.localRouter.path.count == 1)
        #expect(presentingRouter.path.isEmpty)
    }

    @MainActor
    @Test
    func navigationRootCanBeConstructed() {
        let appFlowCoordinator = makeTestAppFlowCoordinator(
            visibleFlow: .main
        )
        let appFlowRouter = appFlowCoordinator.appFlowRouter
        let router = AppRouter(
            appFlowRouter: appFlowRouter
        )
        let onboardingRouter = FlowRouter(appFlowCoordinator: appFlowCoordinator)
        let maintenanceRouter = FlowRouter(appFlowCoordinator: appFlowCoordinator)
        let legacyRouter = FlowRouter(appFlowCoordinator: appFlowCoordinator)
        let session = SessionPresentation(state: .guest, revision: 1)
        let settings = SettingsDependencies(
            appInfo: AppInfoService(
                displayName: "AppTemplate",
                version: "1.0"
            )
        )
        let dependencies = AppDependencies.preview(
            settings: settings,
            remoteService: FailClosedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: FailClosedImageLoader()
        )
        let projectSession = ProjectSessionActions()
        let storeDependencies = dependencies.makeStoreDependencies(session: projectSession)
        let storeUISupport = dependencies.storeUISupport

        _ = ContentView(
            appFlowCoordinator: appFlowCoordinator,
            session: session,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport
        )
        _ = AppSceneView(
            appFlowCoordinator: appFlowCoordinator,
            session: session,
            localNotifications: .inMemory(),
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport
        )
        _ = AppRootView(
            appFlowRouter: appFlowRouter,
            router: router,
            onboardingRouter: onboardingRouter,
            maintenanceRouter: maintenanceRouter,
            session: session,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport
        )
        _ = AppShellView(
            router: router,
            session: session,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport
        )
        _ = StoreFlowView(
            router: router.store,
            dependencies: storeDependencies,
            uiSupport: storeUISupport
        )
        _ = ServicesFlowView(router: router.services, session: session)
        let authenticationDependencies = AuthenticationDependencies(
            session: projectSession,
            cancellation: ProjectAuthenticationCancellation()
        )
        _ = AuthenticationView(dependencies: authenticationDependencies)
        _ = AuthenticationFlowView(dependencies: authenticationDependencies)
        _ = AuthenticationHelpView()
        _ = OnboardingFlowView(router: onboardingRouter)
        _ = OnboardingView(router: onboardingRouter)
        _ = HomeFlowView(router: legacyRouter)
        _ = GuideTopicView(id: "screen-owned-routes")
        _ = QuickStartView()
        _ = BrowseFlowView(router: legacyRouter)
        _ = BrowseView(router: legacyRouter)
        _ = BrowseOptionsView()
        _ = BrowseDetailView(id: "source", router: legacyRouter)
        _ = RelatedItemsView(sourceItemID: "source", router: legacyRouter)
        _ = RelatedItemDetailView(id: "related")
        _ = ProjectsFlowView(router: legacyRouter)
        _ = ProjectsView(router: legacyRouter)
        _ = ProjectDetailsView(
            projectID: "project-from-deep-link",
            router: legacyRouter
        )
        _ = TaskDetailsView(
            projectID: "project-from-deep-link",
            taskID: "task-from-restored-navigation"
        )
        let createProjectFlowState = CreateProjectFlowState()
        _ = CreateProjectFlowView(appFlowCoordinator: legacyRouter)
        _ = ProjectInfoView(projectID: "project-from-deep-link")
        _ = ProjectBasicsView(
            router: makeTestFlowRouter(),
            flowState: createProjectFlowState
        )
        _ = ProjectOptionsView(
            router: makeTestFlowRouter(),
            flowState: createProjectFlowState
        )
        _ = ProjectReviewView(flowState: createProjectFlowState)
        _ = SettingsFlowView(
            router: legacyRouter,
            dependencies: settings
        )
        _ = SettingsView(
            router: legacyRouter,
            dependencies: settings
        )
        _ = AboutView(router: legacyRouter)
        _ = PlatformDetailsView(platform: .macOS)
        _ = SessionInfoView()
        _ = MaintenanceFlowView(router: maintenanceRouter)
        _ = MaintenanceView(router: maintenanceRouter)
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

#if os(macOS)
extension ProjectConfigurationTests {
    @MainActor
    @Test
    func completingCreateProjectFlowDismissesItsContainingSheet() async throws {
        let flowState = CreateProjectFlowState()
        let presentation = CreateProjectSheetPresentation()
        let controller = NSHostingController(
            rootView: CreateProjectSheetHarness(
                presentation: presentation,
                flowState: flowState,
                appFlowCoordinator: makeTestFlowRouter()
            )
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.makeKeyAndOrderFront(nil)
        defer {
            window.close()
        }

        let didPresent = try await eventually {
            window.attachedSheet != nil
        }
        #expect(didPresent)

        ProjectReviewViewModel(flowState: flowState).finish()

        let didDismiss = try await eventually {
            !presentation.isPresented && window.attachedSheet == nil
        }

        #expect(didDismiss)
    }
}

@MainActor
@Observable
private final class CreateProjectSheetPresentation {
    var isPresented = true
}

private struct CreateProjectSheetHarness: View {
    @Bindable var presentation: CreateProjectSheetPresentation
    let flowState: CreateProjectFlowState
    let appFlowCoordinator: any IAppFlowCoordinator

    var body: some View {
        Color.clear
            .sheet(isPresented: $presentation.isPresented) {
                CreateProjectFlowView(
                    flowState: flowState,
                    appFlowCoordinator: appFlowCoordinator
                )
            }
    }
}

@MainActor
private func eventually(
    _ condition: @escaping @MainActor () -> Bool
) async throws -> Bool {
    for _ in 0..<100 {
        if condition() {
            return true
        }
        try await Task.sleep(for: .milliseconds(20))
    }
    return condition()
}
#endif

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
}
