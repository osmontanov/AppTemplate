import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct AppRouterTests {
    @Test
    func everyFlowRouterDelegatesToTheSharedAppFlowRouter() {
        let appFlowRouter = AppFlowRouter(flow: .main)
        let router = AppRouter(
            appFlowRouter: appFlowRouter,
            selectedSection: .settings
        )

        router.authentication.setFlow(.authentication)
        let authenticationTransition = appFlowRouter.transition
        router.onboarding.setFlow(.onboarding)
        let onboardingTransition = appFlowRouter.transition
        router.home.setFlow(.main)
        let homeTransition = appFlowRouter.transition
        router.browse.setFlow(.authentication)
        let browseTransition = appFlowRouter.transition
        router.projects.setFlow(.main)
        let projectsTransition = appFlowRouter.transition
        router.settings.setFlow(.authentication)
        let settingsTransition = appFlowRouter.transition
        router.maintenance.setFlow(.maintenance)
        let maintenanceTransition = appFlowRouter.transition

        #expect(router.appFlowRouter === appFlowRouter)
        #expect(router.selectedSection == .settings)
        #expect(authenticationTransition.flow == .authentication)
        #expect(onboardingTransition.flow == .onboarding)
        #expect(homeTransition.flow == .main)
        #expect(browseTransition.flow == .authentication)
        #expect(projectsTransition.flow == .main)
        #expect(settingsTransition.flow == .authentication)
        #expect(maintenanceTransition.flow == .maintenance)
        #expect(
            Set(
                [
                    authenticationTransition.id,
                    onboardingTransition.id,
                    homeTransition.id,
                    browseTransition.id,
                    projectsTransition.id,
                    settingsTransition.id,
                    maintenanceTransition.id
                ]
            ).count == 7
        )
        #expect(appFlowRouter.flow == .maintenance)
    }

    @Test
    func browseIntentSelectsBrowseAndBuildsCanonicalPath() {
        let router = makeRouter()

        let outcome = router.handle(.browseItem(id: "swiftui"))

        #expect(outcome == .applied)
        #expect(router.selectedSection == .browse)
        #expect(router.browse.path.count == 1)
    }

    @Test
    func unknownBrowseIdentifierStillBuildsRouteAndPreservesOtherFlows() {
        let router = makeRouter(selectedSection: .settings)
        router.home.push(HomeRoute.details)
        router.settings.push(SettingsRoute.about)

        let outcome = router.handle(.browseItem(id: "missing"))

        #expect(outcome == .applied)
        #expect(router.selectedSection == .browse)
        #expect(router.browse.path.count == 1)
        #expect(router.home.path.count == 1)
        #expect(router.settings.path.count == 1)
    }

    @Test
    func projectIntentResetsOnlyProjectsHistoryAndPreservesOtherFlows() {
        let router = makeRouter(selectedSection: .settings)
        router.home.push(HomeRoute.details)
        router.browse.push(BrowseRoute.item(id: "swiftui"))
        router.projects.push(ProjectsRoute.project(id: "stale-project"))
        router.projects.push(
            ProjectDetailsRoute.task(
                projectID: "stale-project",
                taskID: "stale-task"
            )
        )
        router.settings.push(SettingsRoute.about)

        let outcome = router.handle(.project(id: "missing-project"))

        #expect(outcome == .applied)
        #expect(router.selectedSection == .projects)
        #expect(router.projects.path.count == 1)
        #expect(router.home.path.count == 1)
        #expect(router.browse.path.count == 1)
        #expect(router.settings.path.count == 1)
    }

    @Test
    func projectTaskIntentBuildsCanonicalProjectsRouteSequence() {
        let router = makeRouter()
        router.projects.push(ProjectsRoute.project(id: "stale-project"))

        let outcome = router.handle(
            .projectTask(projectID: "project-1", taskID: "missing-task")
        )

        #expect(outcome == .applied)
        #expect(router.selectedSection == .projects)
        #expect(router.projects.path.count == 2)
    }

    @Test
    func projectTaskIntentDefersAndReplaysAfterAuthentication() {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let router = AppRouter(appFlowRouter: appFlowRouter)

        #expect(
            router.handle(.projectTask(projectID: "project-1", taskID: "task-1"))
                == .deferred
        )
        #expect(
            router.pendingIntent
                == .projectTask(projectID: "project-1", taskID: "task-1")
        )

        appFlowRouter.setFlow(.main)
        #expect(router.apply(appFlowRouter.transition) == .applied)
        #expect(router.pendingIntent == nil)
        #expect(router.selectedSection == .projects)
        #expect(router.projects.path.count == 2)
    }

    @Test
    func successfulNewAuthenticationResetsHistoriesBeforeReplayingIntent() {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let router = AppRouter(appFlowRouter: appFlowRouter)
        router.authentication.push(AuthenticationTestRoute.step)
        router.home.push(HomeRoute.details)
        router.settings.push(SettingsRoute.about)
        router.projects.push(ProjectsRoute.project(id: "project-1"))
        _ = router.handle(.browseItem(id: "swiftui"))

        appFlowRouter.setFlow(.main)
        let outcome = router.apply(appFlowRouter.transition)

        #expect(outcome == .applied)
        #expect(appFlowRouter.flow == .main)
        #expect(router.pendingIntent == nil)
        #expect(router.authentication.path.isEmpty)
        #expect(router.home.path.isEmpty)
        #expect(router.settings.path.isEmpty)
        #expect(router.projects.path.isEmpty)
        #expect(router.browse.path.count == 1)
        #expect(router.selectedSection == .browse)
    }

    @Test
    func discardTransitionClearsPendingIntentAndAuthenticationHistory() {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let router = AppRouter(appFlowRouter: appFlowRouter)
        router.authentication.push(AuthenticationTestRoute.step)
        _ = router.handle(.selectSection(.settings))

        appFlowRouter.setFlow(.authentication)

        #expect(router.apply(appFlowRouter.transition) == nil)
        #expect(router.pendingIntent == nil)
        #expect(appFlowRouter.flow == .authentication)
        #expect(router.authentication.path.isEmpty)
    }

    @Test
    func explicitFlowTransitionResetsEveryHistory() {
        let appFlowRouter = AppFlowRouter(flow: .main)
        let router = AppRouter(appFlowRouter: appFlowRouter)
        router.home.push(HomeRoute.details)
        router.browse.push(BrowseRoute.item(id: "swiftui"))
        router.projects.push(ProjectsRoute.project(id: "project-1"))
        router.settings.push(SettingsRoute.about)

        appFlowRouter.setFlow(.authentication)
        _ = router.apply(appFlowRouter.transition)

        #expect(appFlowRouter.flow == .authentication)
        #expect(router.selectedSection == .home)
        #expect(router.authentication.path.isEmpty)
        #expect(router.home.path.isEmpty)
        #expect(router.browse.path.isEmpty)
        #expect(router.projects.path.isEmpty)
        #expect(router.settings.path.isEmpty)
    }

    @Test
    func schemaThreeRestoreReplacesExistingProjectsHistory() throws {
        let source = makeRouter(selectedSection: .projects)
        source.projects.push(ProjectsRoute.project(id: "project-1"))
        let restored = makeRouter()
        restored.projects.push(ProjectsRoute.project(id: "stale-project"))
        restored.projects.push(
            ProjectDetailsRoute.task(
                projectID: "stale-project",
                taskID: "task-1"
            )
        )

        #expect(
            restored.restore(
                from: try NavigationSnapshotCodec.encode(source.snapshot)
            ) == .restored
        )
        #expect(restored.projects.path.count == 1)
    }

    @Test
    func multipleScenesShareRootFlowButKeepIndependentRouterState() {
        let appFlowRouter = AppFlowRouter(flow: .main)
        let firstScene = AppRouter(appFlowRouter: appFlowRouter)
        let secondScene = AppRouter(appFlowRouter: appFlowRouter)

        _ = firstScene.handle(.browseItem(id: "swiftui"))

        #expect(firstScene.appFlowRouter === secondScene.appFlowRouter)
        #expect(firstScene.selectedSection == .browse)
        #expect(firstScene.browse.path.count == 1)
        #expect(secondScene.selectedSection == .home)
        #expect(secondScene.browse.path.isEmpty)
    }

    private func makeRouter(
        flow: AppFlow = .main,
        selectedSection: AppSection = .home
    ) -> AppRouter {
        AppRouter(
            appFlowRouter: AppFlowRouter(flow: flow),
            selectedSection: selectedSection
        )
    }
}

private
nonisolated
enum AuthenticationTestRoute: String, NavigationRoute {
    case step
}
