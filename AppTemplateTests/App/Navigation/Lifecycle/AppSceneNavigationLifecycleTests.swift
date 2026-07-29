import Foundation
import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct AppSceneNavigationLifecycleTests {
    @Test
    func coldLaunchURLsApplyInArrivalOrderAfterRestoration() throws {
        let stored = AppRouter(selectedSection: .home)
        stored.home.push(HomeRoute.details)
        let router = AppRouter()
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
        #expect(snapshotToPersist == router.snapshot)
    }

    @Test
    func unknownColdLaunchURLFallsBackToHomeAndPreservesOtherHistories() throws {
        let stored = AppRouter(selectedSection: .settings)
        stored.home.push(HomeRoute.details)
        stored.browse.push(BrowseRoute.item(id: "swiftui"))
        stored.settings.push(SettingsRoute.about)
        let router = AppRouter()
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
        #expect(snapshotToPersist == router.snapshot)
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
        let router = AppRouter()
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
    func unknownBrowseRecordColdLaunchKeepsRouteAndOtherHistories() throws {
        let stored = AppRouter(selectedSection: .settings)
        stored.home.push(HomeRoute.details)
        stored.browse.push(BrowseRoute.item(id: "swiftui"))
        stored.settings.push(SettingsRoute.about)
        let router = AppRouter()
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
        #expect(snapshotToPersist == router.snapshot)
    }

    @Test
    func authenticationGatedColdLaunchIntentRemainsPending() throws {
        let router = AppRouter(flow: .authentication)
        let lifecycle = AppSceneNavigationLifecycle(router: router)

        lifecycle.receive(
            try #require(URL(string: "apptemplate://browse/item/swiftui"))
        )
        _ = lifecycle.restore(from: nil)

        #expect(router.pendingIntent == .browseItem(id: "swiftui"))
        #expect(router.selectedSection == .home)
    }

    @Test
    func signedOutColdLaunchIntentReplaysAfterAuthentication() throws {
        let router = AppRouter(flow: .launching)
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        let session = UserSession(id: "one", displayName: "One")

        lifecycle.receive(
            try #require(URL(string: "apptemplate://browse/item/swiftui"))
        )
        _ = lifecycle.restore(from: nil)
        lifecycle.synchronizeSession(.unauthenticated)

        #expect(router.flow == .authentication)
        #expect(router.pendingIntent == .browseItem(id: "swiftui"))

        lifecycle.synchronizeSession(.loading)
        lifecycle.synchronizeSession(.authenticated(session))

        #expect(router.flow == .main)
        #expect(router.pendingIntent == nil)
        #expect(router.selectedSection == .browse)
        #expect(router.browse.path.count == 1)
    }

    @Test
    func lastQueuedURLWinsAfterAuthenticationAndOldHistoriesReset() throws {
        let router = AppRouter(flow: .authentication)
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        _ = lifecycle.restore(from: nil)
        router.home.push(HomeRoute.details)
        router.settings.push(SettingsRoute.about)

        lifecycle.receive(
            try #require(URL(string: "apptemplate://settings/not-a-route"))
        )
        lifecycle.receive(
            try #require(URL(string: "apptemplate://browse/item/swiftui"))
        )
        let outcome = router.completeAuthentication(succeeded: true)

        #expect(outcome == .applied)
        #expect(router.selectedSection == .browse)
        #expect(router.home.path.isEmpty)
        #expect(router.browse.path.count == 1)
        #expect(router.settings.path.isEmpty)
    }

    @Test
    func sharedAuthenticatedPhaseReplaysEachScenesOwnPendingIntent() {
        let firstRouter = AppRouter(flow: .authentication)
        let secondRouter = AppRouter(flow: .authentication)
        let first = AppSceneNavigationLifecycle(router: firstRouter)
        let second = AppSceneNavigationLifecycle(router: secondRouter)
        _ = firstRouter.handle(.browseItem(id: "swiftui"))
        _ = secondRouter.handle(.selectSection(.settings))
        let session = UserSession(id: "one", displayName: "One")

        first.synchronizeSession(.authenticated(session))
        second.synchronizeSession(.authenticated(session))

        #expect(firstRouter.browse.path.count == 1)
        #expect(firstRouter.selectedSection == .browse)
        #expect(secondRouter.browse.path.isEmpty)
        #expect(secondRouter.selectedSection == .settings)
    }

    @Test
    func unauthenticatedPhaseResetsEverySceneToAuthentication() {
        let first = AppSceneNavigationLifecycle(router: AppRouter())
        let second = AppSceneNavigationLifecycle(router: AppRouter())
        first.router.home.push(HomeRoute.details)
        second.router.settings.push(SettingsRoute.about)

        first.synchronizeSession(.unauthenticated)
        second.synchronizeSession(.unauthenticated)

        #expect(first.router.flow == .authentication)
        #expect(second.router.flow == .authentication)
        #expect(first.router.home.path.isEmpty)
        #expect(second.router.settings.path.isEmpty)
        #expect(first.router !== second.router)
    }

    @Test
    func authenticatedColdLaunchPreservesRestoredHistory() {
        let router = AppRouter(flow: .launching)
        router.home.push(HomeRoute.details)
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        let session = UserSession(id: "one", displayName: "One")

        lifecycle.synchronizeSession(.authenticated(session))

        #expect(router.flow == .main)
        #expect(router.home.path.count == 1)
    }

    @Test
    func sceneRestorationKeepsProjectsPathsIsolated() throws {
        let firstStored = AppRouter(selectedSection: .projects)
        firstStored.projects.push(ProjectsRoute.project(id: "project-1"))
        let secondStored = AppRouter(selectedSection: .projects)
        secondStored.projects.push(ProjectsRoute.project(id: "project-2"))
        secondStored.projects.push(
            ProjectDetailsRoute.task(
                projectID: "project-2",
                taskID: "task-2"
            )
        )
        let first = AppSceneNavigationLifecycle(router: AppRouter())
        let second = AppSceneNavigationLifecycle(router: AppRouter())

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
    func schemaTwoLifecycleRestorationReturnsSchemaThreeReplacement() throws {
        let legacy = NavigationSnapshotV2(
            selectedSection: .home,
            homePath: FlowPathSnapshot(
                path: NavigationPath([HomeRoute.details])
            ),
            browsePath: FlowPathSnapshot(path: NavigationPath()),
            settingsPath: FlowPathSnapshot(path: NavigationPath())
        )
        let lifecycle = AppSceneNavigationLifecycle(router: AppRouter())
        let replacement = lifecycle.restore(
            from: try JSONEncoder().encode(legacy)
        )

        #expect(
            try NavigationSnapshotCodec.schemaVersion(
                in: NavigationSnapshotCodec.encode(#require(replacement))
            ) == 3
        )
        #expect(lifecycle.router.home.path.count == 1)
        #expect(lifecycle.router.projects.path.isEmpty)
    }

    @Test
    func defaultLifecycleStartsInLaunchingFlow() {
        let lifecycle = AppSceneNavigationLifecycle()

        #expect(lifecycle.router.flow == .launching)
    }
}

private nonisolated struct NavigationSnapshotV2: Encodable {
    let schemaVersion = 2
    let selectedSection: AppSection
    let homePath: FlowPathSnapshot
    let browsePath: FlowPathSnapshot
    let settingsPath: FlowPathSnapshot
}
