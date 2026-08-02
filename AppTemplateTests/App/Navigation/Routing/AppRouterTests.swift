import Foundation
import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct AppRouterTests {
    @Test
    func everyFlowRouterDelegatesToTheSharedAppFlowCoordinator() {
        let appFlowRouter = AppFlowRouter(flow: .main)
        let coordinator = AppFlowCoordinatorSpy()
        let router = AppRouter(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator,
            selectedSection: .settings
        )

        router.onboarding.completeOnboarding()
        router.home.restartOnboarding()
        router.browse.signIn()
        router.projects.signOut()
        router.settings.setMaintenanceEnabled(true)
        router.maintenance.setMaintenanceEnabled(false)

        #expect(router.appFlowRouter === appFlowRouter)
        #expect(router.selectedSection == .settings)
        #expect(coordinator.commands == [
            .completeOnboarding,
            .restartOnboarding,
            .signIn,
            .signOut,
            .setMaintenanceEnabled(true),
            .setMaintenanceEnabled(false)
        ])
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
        let router = AppRouter(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: AppFlowCoordinatorSpy()
        )

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
    func mainRootTransitionResetsHistoriesBeforeReplayingIntent() {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let router = AppRouter(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: AppFlowCoordinatorSpy()
        )
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
        let router = AppRouter(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: AppFlowCoordinatorSpy()
        )
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
        let router = AppRouter(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: AppFlowCoordinatorSpy()
        )
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
        let coordinator = AppFlowCoordinatorSpy()
        let firstScene = AppRouter(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        let secondScene = AppRouter(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )

        _ = firstScene.handle(.browseItem(id: "swiftui"))

        #expect(firstScene.appFlowRouter === secondScene.appFlowRouter)
        #expect(firstScene.selectedSection == .browse)
        #expect(firstScene.browse.path.count == 1)
        #expect(secondScene.selectedSection == .home)
        #expect(secondScene.browse.path.isEmpty)
    }

    @Test
    func deferredIntentSurvivesOnboardingAndAuthenticationGates() throws {
        let storage = AppStateStorageSpy()
        let store = AppStateStore(storage: storage)
        let appFlowRouter = AppFlowRouter(flow: .onboarding)
        let coordinator = AppFlowCoordinator(
            store: store,
            appFlowRouter: appFlowRouter
        )
        let router = AppRouter(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        #expect(router.handle(.browseItem(id: "swiftui")) == .deferred)

        coordinator.completeOnboarding()
        _ = router.apply(appFlowRouter.transition)
        #expect(router.pendingIntent == .browseItem(id: "swiftui"))

        coordinator.signIn()
        #expect(router.apply(appFlowRouter.transition) == .applied)
        #expect(router.pendingIntent == nil)
        #expect(router.selectedSection == .browse)
        #expect(router.browse.path.count == 1)
    }

    @Test
    func deferredIntentSurvivesAuthenticationAndMaintenanceGates() throws {
        let state = AppState(
            isAuthenticated: false,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let storage = AppStateStorageSpy(
            loadResult: .data(try JSONEncoder().encode(state))
        )
        let store = AppStateStore(storage: storage)
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let coordinator = AppFlowCoordinator(
            store: store,
            appFlowRouter: appFlowRouter
        )
        let router = AppRouter(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        #expect(
            router.handle(
                .projectTask(projectID: "project-1", taskID: "task-1")
            ) == .deferred
        )

        coordinator.signIn()
        _ = router.apply(appFlowRouter.transition)

        #expect(appFlowRouter.flow == .maintenance)
        #expect(
            router.pendingIntent
                == .projectTask(projectID: "project-1", taskID: "task-1")
        )

        coordinator.setMaintenanceEnabled(false)
        #expect(router.apply(appFlowRouter.transition) == .applied)
        #expect(router.pendingIntent == nil)
        #expect(router.selectedSection == .projects)
        #expect(router.projects.path.count == 2)
    }

    @Test
    func sharedCoordinatorReplaysEachScenesOwnPendingIntent() throws {
        let state = AppState(
            isAuthenticated: false,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let storage = AppStateStorageSpy(
            loadResult: .data(try JSONEncoder().encode(state))
        )
        let store = AppStateStore(storage: storage)
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let coordinator = AppFlowCoordinator(
            store: store,
            appFlowRouter: appFlowRouter
        )
        let first = AppRouter(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        let second = AppRouter(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        _ = first.handle(.browseItem(id: "swiftui"))
        _ = second.handle(
            .projectTask(projectID: "project-1", taskID: "task-1")
        )

        coordinator.signIn()
        _ = first.apply(appFlowRouter.transition)
        _ = second.apply(appFlowRouter.transition)

        #expect(first.selectedSection == .browse)
        #expect(first.browse.path.count == 1)
        #expect(first.projects.path.isEmpty)
        #expect(second.selectedSection == .projects)
        #expect(second.projects.path.count == 2)
        #expect(second.browse.path.isEmpty)
    }

    @Test
    func cancellingAuthenticationClearsOnlyTheCancellingScene() {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let coordinator = AppFlowCoordinatorSpy()
        let firstScene = AppRouter(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        let secondScene = AppRouter(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        firstScene.authentication.push(AuthenticationTestRoute.step)
        secondScene.authentication.push(AuthenticationTestRoute.step)
        _ = firstScene.handle(.selectSection(.browse))
        _ = secondScene.handle(.selectSection(.settings))
        let transition = appFlowRouter.transition

        firstScene.cancelAuthentication()

        #expect(firstScene.authentication.path.isEmpty)
        #expect(firstScene.pendingIntent == nil)
        #expect(secondScene.authentication.path.count == 1)
        #expect(secondScene.pendingIntent == .selectSection(.settings))
        #expect(appFlowRouter.transition == transition)
    }

    private func makeRouter(
        flow: AppFlow = .main,
        selectedSection: AppSection = .home
    ) -> AppRouter {
        AppRouter(
            appFlowRouter: AppFlowRouter(flow: flow),
            appFlowCoordinator: AppFlowCoordinatorSpy(),
            selectedSection: selectedSection
        )
    }
}

private
nonisolated
enum AuthenticationTestRoute: String, NavigationRoute {
    case step
}
