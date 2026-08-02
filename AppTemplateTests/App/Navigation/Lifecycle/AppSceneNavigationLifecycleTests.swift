import Foundation
import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct AppSceneNavigationLifecycleTests {
    @Test
    func coldLaunchURLsApplyInArrivalOrderAfterRestoration() throws {
        let stored = makeRouter(selectedSection: .home)
        stored.home.push(HomeRoute.details)
        let router = makeRouter()
        let lifecycle = AppSceneNavigationLifecycle(router: router)

        lifecycle.receive(
            try #require(URL(string: "apptemplate://browse/item/swiftui"))
        )
        lifecycle.receive(
            try #require(URL(string: "apptemplate://settings"))
        )
        let snapshotToPersist = lifecycle.restore(
            from: try NavigationSnapshotCodec.encode(stored.snapshot)
        )

        #expect(router.selectedSection == .settings)
        #expect(router.home.path.count == 1)
        #expect(router.browse.path.count == 1)
        #expect(snapshotToPersist == lifecycle.snapshot)
    }

    @Test
    func unknownColdLaunchURLFallsBackToHomeAndPreservesOtherHistories() throws {
        let stored = makeRouter(selectedSection: .settings)
        stored.home.push(HomeRoute.details)
        stored.browse.push(BrowseRoute.item(id: "swiftui"))
        stored.settings.push(SettingsRoute.about)
        let router = makeRouter()
        let lifecycle = AppSceneNavigationLifecycle(router: router)

        lifecycle.receive(
            try #require(URL(string: "apptemplate://unknown"))
        )
        let snapshotToPersist = lifecycle.restore(
            from: try NavigationSnapshotCodec.encode(stored.snapshot)
        )

        #expect(router.selectedSection == .home)
        #expect(router.home.path.isEmpty)
        #expect(router.browse.path.count == 1)
        #expect(router.settings.path.count == 1)
        #expect(snapshotToPersist == lifecycle.snapshot)
    }

    @Test(arguments: [
        ("apptemplate://home/not-a-route", AppSection.home),
        ("apptemplate://browse/not-a-route", AppSection.browse),
        ("apptemplate://settings/not-a-route", AppSection.settings),
        ("apptemplate://unknown", AppSection.home),
        ("https://example.com/browse", AppSection.home)
    ])
    func rejectedWarmURLFallsBackContextuallyAndPreservesUnrelatedHistories(
        rawURL: String,
        expectedSection: AppSection
    ) throws {
        let router = makeRouter()
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        _ = lifecycle.restore(from: nil)
        router.home.push(HomeRoute.details)
        router.browse.push(BrowseRoute.item(id: "swiftui"))
        router.settings.push(SettingsRoute.about)

        _ = lifecycle.receive(try #require(URL(string: rawURL)))

        #expect(router.selectedSection == expectedSection)
        #expect(
            router.home.path.count == (expectedSection == .home ? 0 : 1)
        )
        #expect(
            router.browse.path.count == (expectedSection == .browse ? 0 : 1)
        )
        #expect(
            router.settings.path.count
                == (expectedSection == .settings ? 0 : 1)
        )
    }

    @Test
    func projectsRootWarmURLResetsOnlyProjectsHistory() throws {
        let router = makeRouter(selectedSection: .settings)
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        _ = lifecycle.restore(from: nil)
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

        _ = lifecycle.receive(
            try #require(URL(string: "apptemplate://projects"))
        )

        #expect(router.selectedSection == .projects)
        #expect(router.projects.path.isEmpty)
        #expect(router.home.path.count == 1)
        #expect(router.browse.path.count == 1)
        #expect(router.settings.path.count == 1)
    }

    @Test
    func unknownBrowseRecordColdLaunchKeepsRouteAndOtherHistories() throws {
        let stored = makeRouter(selectedSection: .settings)
        stored.home.push(HomeRoute.details)
        stored.browse.push(BrowseRoute.item(id: "swiftui"))
        stored.settings.push(SettingsRoute.about)
        let router = makeRouter()
        let lifecycle = AppSceneNavigationLifecycle(router: router)

        lifecycle.receive(
            try #require(URL(string: "apptemplate://browse/item/deleted"))
        )
        let snapshotToPersist = lifecycle.restore(
            from: try NavigationSnapshotCodec.encode(stored.snapshot)
        )

        #expect(router.selectedSection == .browse)
        #expect(router.home.path.count == 1)
        #expect(router.browse.path.count == 1)
        #expect(router.settings.path.count == 1)
        #expect(snapshotToPersist == lifecycle.snapshot)
    }

    @Test
    func authenticationGatedColdLaunchIntentRemainsPending() throws {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let lifecycle = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: AppFlowCoordinatorSpy()
        )

        lifecycle.receive(
            try #require(URL(string: "apptemplate://browse/item/swiftui"))
        )
        _ = lifecycle.restore(from: nil)

        #expect(lifecycle.router.pendingIntent == .browseItem(id: "swiftui"))
        #expect(lifecycle.router.selectedSection == .home)
    }

    @Test
    func authenticationGatedProjectTaskColdLaunchReplaysCanonicalProjectsPath()
        throws {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let lifecycle = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: AppFlowCoordinatorSpy()
        )

        lifecycle.receive(
            try #require(
                URL(
                    string: "apptemplate://projects/project/project-1/task/task-1"
                )
            )
        )
        _ = lifecycle.restore(from: nil)

        #expect(
            lifecycle.router.pendingIntent
                == .projectTask(projectID: "project-1", taskID: "task-1")
        )
        appFlowRouter.setFlow(.main)
        #expect(lifecycle.apply(appFlowRouter.transition) == .applied)
        #expect(lifecycle.router.selectedSection == .projects)
        #expect(lifecycle.router.projects.path.count == 2)
    }

    @Test
    func queuedURLSurvivesCurrentMainResetDuringRestoration() throws {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        appFlowRouter.setFlow(.main)
        let lifecycle = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: AppFlowCoordinatorSpy()
        )
        lifecycle.receive(
            try #require(URL(string: "apptemplate://browse/item/swiftui"))
        )

        let snapshotToPersist = lifecycle.restore(
            from: nil,
            applying: appFlowRouter.transition
        )
        #expect(lifecycle.apply(appFlowRouter.transition) == nil)

        #expect(lifecycle.hasRestored)
        #expect(lifecycle.router.pendingIntent == nil)
        #expect(lifecycle.router.selectedSection == .browse)
        #expect(lifecycle.router.browse.path.count == 1)
        #expect(snapshotToPersist == lifecycle.snapshot)
    }

    @Test
    func queuedURLSurvivesCurrentAuthenticationDiscardThenReplaysExactly()
        throws {
        let appFlowRouter = AppFlowRouter(flow: .main)
        appFlowRouter.setFlow(.authentication)
        let lifecycle = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: AppFlowCoordinatorSpy()
        )
        let intent = NavigationIntent.projectTask(
            projectID: "project-1",
            taskID: "task-1"
        )
        lifecycle.receive(
            try #require(
                URL(
                    string: "apptemplate://projects/project/project-1/task/task-1"
                )
            )
        )

        let snapshotToPersist = lifecycle.restore(
            from: nil,
            applying: appFlowRouter.transition
        )
        #expect(lifecycle.apply(appFlowRouter.transition) == nil)

        #expect(lifecycle.hasRestored)
        #expect(lifecycle.router.pendingIntent == intent)
        #expect(snapshotToPersist == lifecycle.snapshot)

        appFlowRouter.setFlow(.main)
        #expect(lifecycle.apply(appFlowRouter.transition) == .applied)

        let expected = makeRouter()
        #expect(expected.handle(intent) == .applied)
        #expect(lifecycle.router.pendingIntent == nil)
        #expect(lifecycle.router.snapshot == expected.snapshot)
    }

    @Test
    func lastQueuedURLWinsAfterAuthenticationAndOldHistoriesReset() throws {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let lifecycle = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: AppFlowCoordinatorSpy()
        )
        _ = lifecycle.restore(from: nil)
        lifecycle.router.home.push(HomeRoute.details)
        lifecycle.router.settings.push(SettingsRoute.about)

        lifecycle.receive(
            try #require(URL(string: "apptemplate://settings/not-a-route"))
        )
        lifecycle.receive(
            try #require(URL(string: "apptemplate://browse/item/swiftui"))
        )
        appFlowRouter.setFlow(.main)
        let outcome = lifecycle.apply(appFlowRouter.transition)

        #expect(outcome == .applied)
        #expect(lifecycle.router.selectedSection == .browse)
        #expect(lifecycle.router.home.path.isEmpty)
        #expect(lifecycle.router.browse.path.count == 1)
        #expect(lifecycle.router.settings.path.isEmpty)
    }

    @Test
    func mainTransitionReplaysOnlyEachReceivingScenesPendingIntent() throws {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let coordinator = AppFlowCoordinatorSpy()
        let first = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        let second = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        _ = first.restore(
            from: nil,
            applying: appFlowRouter.transition
        )
        _ = second.restore(
            from: nil,
            applying: appFlowRouter.transition
        )
        _ = first.receive(
            try #require(URL(string: "apptemplate://browse/item/swiftui"))
        )
        _ = second.receive(
            try #require(
                URL(
                    string: "apptemplate://projects/project/project-1/task/task-1"
                )
            )
        )

        appFlowRouter.setFlow(.main)
        _ = first.apply(appFlowRouter.transition)
        _ = second.apply(appFlowRouter.transition)

        let expectedFirst = makeRouter()
        expectedFirst.selectedSection = .browse
        expectedFirst.browse.push(BrowseRoute.item(id: "swiftui"))
        let expectedSecond = makeRouter()
        expectedSecond.selectedSection = .projects
        expectedSecond.projects.push(
            ProjectsRoute.project(id: "project-1")
        )
        expectedSecond.projects.push(
            ProjectDetailsRoute.task(
                projectID: "project-1",
                taskID: "task-1"
            )
        )

        #expect(first.router.snapshot == expectedFirst.snapshot)
        #expect(second.router.snapshot == expectedSecond.snapshot)
        #expect(first.router.pendingIntent == nil)
        #expect(second.router.pendingIntent == nil)
        #expect(first.router !== second.router)
    }

    @Test
    func explicitFlowTransitionResetsEverySceneToAuthentication() {
        let appFlowRouter = AppFlowRouter(flow: .main)
        let coordinator = AppFlowCoordinatorSpy()
        let first = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        let second = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        first.router.home.push(HomeRoute.details)
        second.router.projects.push(
            ProjectsRoute.project(id: "template")
        )

        appFlowRouter.setFlow(.authentication)
        _ = first.apply(appFlowRouter.transition)
        _ = second.apply(appFlowRouter.transition)

        #expect(appFlowRouter.flow == .authentication)
        #expect(first.router.home.path.isEmpty)
        #expect(second.router.projects.path.isEmpty)
        #expect(first.router.selectedSection == .home)
        #expect(second.router.selectedSection == .home)
        #expect(first.router !== second.router)
    }

    @Test
    func repeatedDeliveryOfOneTransitionDoesNotResetSceneTwice() {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let lifecycle = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: AppFlowCoordinatorSpy()
        )
        _ = lifecycle.router.handle(.browseItem(id: "swiftui"))
        appFlowRouter.setFlow(.main)

        _ = lifecycle.apply(appFlowRouter.transition)
        _ = lifecycle.apply(appFlowRouter.transition)

        #expect(lifecycle.router.selectedSection == .browse)
        #expect(lifecycle.router.browse.path.count == 1)
    }

    @Test
    func sceneRestorationKeepsProjectsPathsIsolated() throws {
        let firstStored = makeRouter(selectedSection: .projects)
        firstStored.projects.push(ProjectsRoute.project(id: "project-1"))
        let secondStored = makeRouter(selectedSection: .projects)
        secondStored.projects.push(ProjectsRoute.project(id: "project-2"))
        secondStored.projects.push(
            ProjectDetailsRoute.task(
                projectID: "project-2",
                taskID: "task-2"
            )
        )
        let appFlowRouter = AppFlowRouter(flow: .main)
        let coordinator = AppFlowCoordinatorSpy()
        let first = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        let second = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )

        _ = first.restore(
            from: try NavigationSnapshotCodec.encode(firstStored.snapshot)
        )
        _ = second.restore(
            from: try NavigationSnapshotCodec.encode(secondStored.snapshot)
        )

        #expect(first.router.projects.path.count == 1)
        #expect(second.router.projects.path.count == 2)
        #expect(first.router.snapshot != second.router.snapshot)
    }

    @Test
    func schemaTwoLifecycleRestorationReturnsSchemaFourReplacement() throws {
        let legacy = Data(
            #"{"schemaVersion":2,"selectedSection":"settings","homePath":{"data":"WyJBcHBUZW1wbGF0ZS5Ib21lUm91dGUiLCJcImRldGFpbHNcIiJd"},"browsePath":{"data":"WyJBcHBUZW1wbGF0ZS5Ccm93c2VSb3V0ZSIsIntcIml0ZW1cIjp7XCJpZFwiOlwic3dpZnR1aVwifX0iXQ=="},"settingsPath":{"data":"WyJBcHBUZW1wbGF0ZS5TZXR0aW5nc1JvdXRlIiwiXCJhYm91dFwiIl0="}}"#.utf8
        )
        let lifecycle = AppSceneNavigationLifecycle(
            appFlowRouter: AppFlowRouter(flow: .main),
            appFlowCoordinator: AppFlowCoordinatorSpy()
        )
        let replacement = lifecycle.restore(from: legacy)
        let decoded = try NavigationSnapshotCodec.decode(
            NavigationSnapshotCodec.encode(#require(replacement))
        )

        #expect(decoded.schemaVersion == 4)
        #expect(
            decoded.lastAppliedTransitionID
                == lifecycle.router.appFlowRouter.transition.id
        )
        #expect(lifecycle.restorationResult == .migrated(from: 2))
        #expect(lifecycle.router.home.path.count == 1)
        #expect(lifecycle.router.projects.path.isEmpty)
    }

    @Test
    func futureSnapshotDisablesWritesWithoutChangingOriginalBytes() throws {
        let future = Data(#"{"schemaVersion":99,"future":"keep"}"#.utf8)
        var persistedData = future
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter())

        let replacement = lifecycle.restore(from: future)
        lifecycle.router.home.push(HomeRoute.details)
        if let snapshot = lifecycle.snapshotForPersistence {
            persistedData = try NavigationSnapshotCodec.encode(snapshot)
        }

        #expect(replacement == nil)
        #expect(lifecycle.snapshotForPersistence == nil)
        #expect(lifecycle.restorationResult == .preservedFutureSchema(99))
        #expect(persistedData == future)
    }

    @Test
    func recreatedSceneSkipsItsPersistedRootTransitionCheckpoint() throws {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        appFlowRouter.setFlow(.main)
        let transition = appFlowRouter.transition
        let coordinator = AppFlowCoordinatorSpy()
        let original = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        _ = original.restore(from: nil, applying: transition)
        original.router.home.push(HomeRoute.details)
        let persisted = try NavigationSnapshotCodec.encode(original.snapshot)
        let recreated = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )

        let replacement = recreated.restore(
            from: persisted,
            applying: transition
        )
        recreated.router.home.push(HomeDetailsRoute.navigationGuide)

        #expect(replacement == nil)
        #expect(recreated.restorationResult == .restored)
        #expect(recreated.router.home.path.count == 2)
        #expect(recreated.snapshot.lastAppliedTransitionID == transition.id)
        #expect(recreated.apply(transition) == nil)
        #expect(recreated.router.home.path.count == 2)
    }

    @Test
    func onboardingAndAuthenticationGatesPreserveThenReplayURL() throws {
        let coordinator = makeTestAppFlowCoordinator()
        let appFlowRouter = coordinator.appFlowRouter
        let lifecycle = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        _ = lifecycle.receive(
            try #require(
                URL(string: "apptemplate://browse/item/swiftui")
            )
        )
        _ = lifecycle.restore(from: nil)

        coordinator.completeOnboarding()
        _ = lifecycle.apply(appFlowRouter.transition)

        #expect(appFlowRouter.flow == .authentication)
        #expect(
            lifecycle.router.pendingIntent == .browseItem(id: "swiftui")
        )

        coordinator.signIn()
        #expect(lifecycle.apply(appFlowRouter.transition) == .applied)
        #expect(lifecycle.router.pendingIntent == nil)
        #expect(lifecycle.router.selectedSection == .browse)
        #expect(lifecycle.router.browse.path.count == 1)
    }

    @Test
    func authenticationAndMaintenanceGatesPreserveThenReplayURL() throws {
        let state = AppState(
            isAuthenticated: false,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let coordinator = makeTestAppFlowCoordinator(state: state)
        let appFlowRouter = coordinator.appFlowRouter
        let lifecycle = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        _ = lifecycle.receive(
            try #require(
                URL(
                    string: "apptemplate://projects/project/project-1/task/task-1"
                )
            )
        )
        _ = lifecycle.restore(from: nil)

        coordinator.signIn()
        _ = lifecycle.apply(appFlowRouter.transition)

        #expect(appFlowRouter.flow == .maintenance)
        #expect(
            lifecycle.router.pendingIntent
                == .projectTask(projectID: "project-1", taskID: "task-1")
        )

        coordinator.setMaintenanceEnabled(false)
        #expect(lifecycle.apply(appFlowRouter.transition) == .applied)
        #expect(lifecycle.router.pendingIntent == nil)
        #expect(lifecycle.router.selectedSection == .projects)
        #expect(lifecycle.router.projects.path.count == 2)
    }

    @Test
    func effectiveSignOutDiscardsURLWhenAuthenticationIsAlreadyVisible()
        throws {
        let state = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let coordinator = makeTestAppFlowCoordinator(
            state: state,
            visibleFlow: .authentication
        )
        let appFlowRouter = coordinator.appFlowRouter
        let lifecycle = AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter,
            appFlowCoordinator: coordinator
        )
        _ = lifecycle.receive(
            try #require(
                URL(string: "apptemplate://browse/item/swiftui")
            )
        )
        _ = lifecycle.restore(from: nil)
        let previousID = appFlowRouter.transition.id

        coordinator.signOut()
        _ = lifecycle.apply(appFlowRouter.transition)

        #expect(appFlowRouter.flow == .authentication)
        #expect(appFlowRouter.transition.id != previousID)
        #expect(
            appFlowRouter.transition.pendingIntentAction == .discard
        )
        #expect(lifecycle.router.pendingIntent == nil)
        #expect(lifecycle.router.browse.path.isEmpty)
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
