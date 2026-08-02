import Foundation
import Observation
import SwiftUI
import Testing
@testable import AppTemplate

#if os(macOS)
import AppKit
#endif

struct ProjectConfigurationTests {
    @Test
    func testTargetLoadsApplicationModule() {
        #expect(Bundle.main.bundleIdentifier == "com.oneday.AppTemplate")
    }

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
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: appFlowCoordinator
        )
        let settings = SettingsDependencies(
            appInfo: AppInfoService(
                displayName: "AppTemplate",
                version: "1.0"
            )
        )

        _ = ContentView(
            appFlowCoordinator: appFlowCoordinator,
            settings: settings
        )
        _ = AppSceneView(
            appFlowCoordinator: appFlowCoordinator,
            settings: settings
        )
        _ = AppRootView(
            appFlowRouter: appFlowRouter,
            router: router,
            settings: settings
        )
        _ = AppShellView(router: router, settings: settings)
        _ = AuthenticationFlowView(
            router: router.authentication,
            authenticationCancellation: router
        )
        _ = AuthenticationHelpView()
        _ = OnboardingFlowView(router: router.onboarding)
        _ = OnboardingView(router: router.onboarding)
        _ = HomeFlowView(router: router.home)
        _ = GuideTopicView(id: "screen-owned-routes")
        _ = QuickStartView()
        _ = BrowseFlowView(router: router.browse)
        _ = BrowseView(router: router.browse)
        _ = BrowseOptionsView()
        _ = BrowseDetailView(id: "source", router: router.browse)
        _ = RelatedItemsView(sourceItemID: "source", router: router.browse)
        _ = RelatedItemDetailView(id: "related")
        _ = ProjectsFlowView(router: router.projects)
        _ = ProjectsView(router: router.projects)
        _ = ProjectDetailsView(
            projectID: "project-from-deep-link",
            router: router.projects
        )
        _ = TaskDetailsView(
            projectID: "project-from-deep-link",
            taskID: "task-from-restored-navigation"
        )
        let createProjectFlowState = CreateProjectFlowState()
        _ = CreateProjectFlowView(appFlowCoordinator: router.projects)
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
            router: router.settings,
            dependencies: settings
        )
        _ = SettingsView(
            router: router.settings,
            dependencies: settings
        )
        _ = AboutView(router: router.settings)
        _ = PlatformDetailsView(name: "macOS 26")
        _ = SessionInfoView()
        _ = MaintenanceFlowView(router: router.maintenance)
        _ = MaintenanceView(router: router.maintenance)
    }
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
