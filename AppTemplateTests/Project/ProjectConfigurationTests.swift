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
    func createProjectFlowForwardsGlobalFlowFromItsNormalInitializer() {
        let appFlowRouter = CreateProjectAppFlowRouterSpy()
        let presentingRouter = FlowRouter(appFlowRouter: appFlowRouter)
        let flow = CreateProjectFlowView(
            store: ProjectsStore(),
            appFlowRouter: presentingRouter
        )

        flow.localRouter.push(ProjectBasicsRoute.options)
        flow.localRouter.setFlow(.onboarding)

        #expect(flow.localRouter.path.count == 1)
        #expect(presentingRouter.path.isEmpty)
        #expect(appFlowRouter.receivedFlows == [.onboarding])
    }

    @MainActor
    @Test
    func createProjectFlowForwardsGlobalFlowFromItsDraftInitializer() {
        let appFlowRouter = CreateProjectAppFlowRouterSpy()
        let presentingRouter = FlowRouter(appFlowRouter: appFlowRouter)
        let flow = CreateProjectFlowView(
            store: ProjectsStore(),
            draft: CreateProjectDraftState(),
            appFlowRouter: presentingRouter
        )

        flow.localRouter.push(ProjectBasicsRoute.options)
        flow.localRouter.setFlow(.maintenance)

        #expect(flow.localRouter.path.count == 1)
        #expect(presentingRouter.path.isEmpty)
        #expect(appFlowRouter.receivedFlows == [.maintenance])
    }

    @MainActor
    @Test
    func navigationRootCanBeConstructed() {
        let appFlowRouter = AppFlowRouter(flow: .main)
        let router = AppRouter(appFlowRouter: appFlowRouter)
        let dependencies = AppDependencies.preview(
            browseItems: []
        )

        _ = AppSceneView(
            appFlowRouter: appFlowRouter,
            dependencies: dependencies
        )
        _ = AppRootView(
            appFlowRouter: appFlowRouter,
            router: router,
            dependencies: dependencies
        )
        _ = AppShellView(router: router, dependencies: dependencies)
        _ = AuthenticationFlowView(router: router.authentication)
        _ = AuthenticationHelpView()
        _ = OnboardingFlowView(router: router.onboarding)
        _ = OnboardingView(router: router.onboarding)
        _ = HomeFlowView(router: router.home)
        _ = GuideTopicView(id: "screen-owned-routes")
        _ = QuickStartView()
        _ = BrowseFlowView(
            router: router.browse,
            dependencies: dependencies.browse
        )
        let browsePreferences = BrowsePreferencesStore()
        _ = BrowseView(
            router: router.browse,
            dependencies: dependencies.browse,
            preferences: browsePreferences
        )
        _ = BrowseOptionsView(preferences: browsePreferences)
        _ = BrowseDetailView(
            id: "source",
            dependencies: dependencies.browse,
            router: router.browse
        )
        _ = RelatedItemsView(
            sourceItemID: "source",
            dependencies: dependencies.browse,
            router: router.browse
        )
        _ = RelatedItemDetailView(
            id: "related",
            dependencies: dependencies.browse
        )
        _ = ProjectsFlowView(
            router: router.projects,
            dependencies: dependencies.projects
        )
        let projectsStore = ProjectsStore()
        let draft = CreateProjectDraftState()
        _ = CreateProjectFlowView(
            store: projectsStore,
            appFlowRouter: router.projects
        )
        _ = ProjectInfoView(
            projectID: "project-1",
            store: projectsStore
        )
        _ = ProjectInfoView(
            projectID: "missing",
            store: ProjectsStore(projects: [])
        )
        _ = ProjectBasicsView(
            draft: draft,
            router: FlowRouter(),
            store: projectsStore
        )
        _ = ProjectOptionsView(
            draft: draft,
            router: FlowRouter(),
            store: projectsStore
        )
        _ = ProjectReviewView(
            draft: draft,
            store: projectsStore
        )
        _ = SettingsFlowView(router: router.settings)
        _ = SettingsView(router: router.settings)
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
        let store = ProjectsStore(projects: [])
        let draft = CreateProjectDraftState()
        let presentation = CreateProjectSheetPresentation()
        let controller = NSHostingController(
            rootView: CreateProjectSheetHarness(
                presentation: presentation,
                draft: draft,
                store: store,
                appFlowRouter: FlowRouter()
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

        draft.title = "Template"
        let created = try ProjectReviewViewModel(
            draft: draft,
            store: store
        ).save()

        let didDismiss = try await eventually {
            !presentation.isPresented && window.attachedSheet == nil
        }

        #expect(didDismiss)
        #expect(store.projects == [created])
    }
}

@MainActor
@Observable
private final class CreateProjectSheetPresentation {
    var isPresented = true
}

private struct CreateProjectSheetHarness: View {
    @Bindable var presentation: CreateProjectSheetPresentation
    let draft: CreateProjectDraftState
    let store: ProjectsStore
    let appFlowRouter: any IAppFlowRouter

    var body: some View {
        Color.clear
            .sheet(isPresented: $presentation.isPresented) {
                CreateProjectFlowView(
                    store: store,
                    draft: draft,
                    appFlowRouter: appFlowRouter
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

@MainActor
private final class CreateProjectAppFlowRouterSpy: IAppFlowRouter {
    private(set) var receivedFlows: [AppFlow] = []

    func setFlow(_ flow: AppFlow) {
        receivedFlows.append(flow)
    }
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
}
