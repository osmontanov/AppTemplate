import Foundation
import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct NavigationSnapshotTests {
    @Test
    func mixedScreenRoutePathRoundTripsThroughJSON() throws {
        let source = makeRouter(selectedSection: .home)
        source.home.push(HomeRoute.details)
        source.home.push(HomeDetailsRoute.navigationGuide)

        let data = try NavigationSnapshotCodec.encode(source.snapshot)
        let restored = makeRouter()

        #expect(restored.restore(from: data).result == .restored)
        #expect(restored.home.path.count == 2)
        #expect(restored.snapshot == source.snapshot)
    }

    @Test
    func projectsScreenRoutePathRoundTripsThroughJSON() throws {
        let source = makeRouter(selectedSection: .projects)
        source.projects.push(ProjectsRoute.project(id: "project-1"))
        source.projects.push(
            ProjectDetailsRoute.task(
                projectID: "project-1",
                taskID: "task-1"
            )
        )
        let data = try NavigationSnapshotCodec.encode(source.snapshot)
        let restored = makeRouter()

        #expect(restored.restore(from: data).result == .restored)
        #expect(restored.projects.path.count == 2)
    }

    @Test
    func stablePlatformRouteRoundTripsThroughSettingsSnapshot() throws {
        let source = makeRouter(selectedSection: .settings)
        source.settings.push(SettingsRoute.about)
        source.settings.push(AboutRoute.platform(.iPadOS))
        let data = try NavigationSnapshotCodec.encode(source.snapshot)
        let restored = makeRouter()

        #expect(restored.restore(from: data).result == .restored)
        #expect(restored.settings.path.count == 2)
        #expect(
            try decodeAboutRoute(from: restored.snapshot.settingsPath)
                == .platform(.iPadOS)
        )
    }

    @Test
    func legacyPlatformRouteRestoresAsTypedStablePlatform() throws {
        let source = makeRouter(selectedSection: .settings)
        var snapshot = source.snapshot
        snapshot.settingsPath = FlowPathSnapshot(
            restorationData: try legacyAboutSettingsPathData(
                platformName: "iPadOS 26"
            )
        )
        let restored = makeRouter()

        let result = restored.restore(
            from: try NavigationSnapshotCodec.encode(snapshot)
        )

        #expect(result.result == .restored)
        #expect(restored.settings.path.count == 2)
        #expect(
            try decodeAboutRoute(from: restored.snapshot.settingsPath)
                == .platform(.iPadOS)
        )
    }

    @Test
    func schemaThreeSnapshotMigratesAllDurableHistories() throws {
        let legacy = Data(
            #"{"schemaVersion":3,"selectedSection":"settings","homePath":{"data":"WyJBcHBUZW1wbGF0ZS5Ib21lUm91dGUiLCJcImRldGFpbHNcIiJd"},"browsePath":{"data":"WyJBcHBUZW1wbGF0ZS5Ccm93c2VSb3V0ZSIsIntcIml0ZW1cIjp7XCJpZFwiOlwic3dpZnR1aVwifX0iXQ=="},"projectsPath":{"data":"WyJBcHBUZW1wbGF0ZS5Qcm9qZWN0c1JvdXRlIiwie1wicHJvamVjdFwiOntcImlkXCI6XCJwcm9qZWN0LTFcIn19Il0="},"settingsPath":{"data":"WyJBcHBUZW1wbGF0ZS5TZXR0aW5nc1JvdXRlIiwiXCJhYm91dFwiIl0="}}"#.utf8
        )
        let restored = makeRouter()

        let restoration = restored.restore(from: legacy)
        let next = try NavigationSnapshotCodec.decode(
            NavigationSnapshotCodec.encode(restored.snapshot)
        )

        #expect(restoration.result == .migrated(from: 3))
        #expect(restoration.lastAppliedTransitionID == nil)
        #expect(restored.selectedSection == .settings)
        #expect(restored.home.path.count == 1)
        #expect(restored.browse.path.count == 1)
        #expect(restored.projects.path.count == 1)
        #expect(restored.settings.path.count == 1)
        #expect(next.schemaVersion == 4)
        #expect(next.lastAppliedTransitionID == nil)
    }

    @Test
    func schemaTwoSnapshotMigratesThreeHistoriesWithEmptyProjects() throws {
        let legacy = Data(
            #"{"schemaVersion":2,"selectedSection":"settings","homePath":{"data":"WyJBcHBUZW1wbGF0ZS5Ib21lUm91dGUiLCJcImRldGFpbHNcIiJd"},"browsePath":{"data":"WyJBcHBUZW1wbGF0ZS5Ccm93c2VSb3V0ZSIsIntcIml0ZW1cIjp7XCJpZFwiOlwic3dpZnR1aVwifX0iXQ=="},"settingsPath":{"data":"WyJBcHBUZW1wbGF0ZS5TZXR0aW5nc1JvdXRlIiwiXCJhYm91dFwiIl0="}}"#.utf8
        )
        let restored = makeRouter()
        restored.projects.push(ProjectsRoute.project(id: "stale-project"))

        let restoration = restored.restore(from: legacy)
        let next = try NavigationSnapshotCodec.decode(
            NavigationSnapshotCodec.encode(restored.snapshot)
        )

        #expect(restoration.result == .migrated(from: 2))
        #expect(restoration.lastAppliedTransitionID == nil)
        #expect(restored.selectedSection == .settings)
        #expect(restored.home.path.count == 1)
        #expect(restored.browse.path.count == 1)
        #expect(restored.projects.path.isEmpty)
        #expect(restored.settings.path.count == 1)
        #expect(next.schemaVersion == 4)
        #expect(next.lastAppliedTransitionID == nil)
    }

    @Test
    func unchangedSnapshotDoesNotRequestAnotherEncoding() throws {
        let router = makeRouter()
        router.home.push(HomeRoute.details)
        let snapshot = router.snapshot
        let storedData = try NavigationSnapshotCodec.encode(snapshot)

        #expect(
            try NavigationSnapshotCodec.encodingIfChanged(
                snapshot,
                comparedTo: storedData
            ) == nil
        )
    }

    @Test
    func semanticallyUnchangedProjectsPathDoesNotRequestAnotherEncoding() throws {
        let projectIDFirstPath = Data(
            #"["AppTemplate.ProjectsRoute","{\"project\":{\"id\":\"project-1\"}}","AppTemplate.ProjectDetailsRoute","{\"task\":{\"projectID\":\"project-1\",\"taskID\":\"task-1\"}}"]"#.utf8
        )
        let taskIDFirstPath = Data(
            #"["AppTemplate.ProjectsRoute","{\"project\":{\"id\":\"project-1\"}}","AppTemplate.ProjectDetailsRoute","{\"task\":{\"taskID\":\"task-1\",\"projectID\":\"project-1\"}}"]"#.utf8
        )
        var storedSnapshot = makeRouter(selectedSection: .projects).snapshot
        storedSnapshot.projectsPath = FlowPathSnapshot(
            restorationData: projectIDFirstPath
        )
        var candidateSnapshot = storedSnapshot
        candidateSnapshot.projectsPath = FlowPathSnapshot(
            restorationData: taskIDFirstPath
        )

        #expect(storedSnapshot.projectsPath.restoredPath?.count == 2)
        #expect(candidateSnapshot.projectsPath.restoredPath?.count == 2)
        #expect(storedSnapshot.projectsPath == candidateSnapshot.projectsPath)
        #expect(
            try NavigationSnapshotCodec.encodingIfChanged(
                candidateSnapshot,
                comparedTo: NavigationSnapshotCodec.encode(storedSnapshot)
            ) == nil
        )
    }

    @Test
    func changedSnapshotProducesReplacementEncoding() throws {
        let storedRouter = makeRouter()
        let changedRouter = makeRouter(selectedSection: .browse)
        changedRouter.browse.push(BrowseRoute.item(id: "swiftui"))
        let storedData = try NavigationSnapshotCodec.encode(storedRouter.snapshot)
        let candidate = try NavigationSnapshotCodec.encodingIfChanged(
            changedRouter.snapshot,
            comparedTo: storedData
        )
        let replacement = try #require(candidate)

        #expect(
            try NavigationSnapshotCodec.decode(replacement)
                == changedRouter.snapshot
        )
    }

    @Test
    func restorePreservesStructurallyValidUnknownBrowseIdentifiers() throws {
        let source = makeRouter(selectedSection: .browse)
        source.home.push(HomeRoute.details)
        source.browse.push(BrowseRoute.item(id: "swiftui"))
        source.browse.push(BrowseRoute.item(id: "deleted"))
        source.settings.push(SettingsRoute.about)
        let restored = makeRouter()

        let result = restored.restore(
            from: try NavigationSnapshotCodec.encode(source.snapshot)
        )

        #expect(result.result == .restored)
        #expect(restored.snapshot == source.snapshot)
        #expect(restored.browse.path.count == 2)
    }

    @Test
    func corruptDataResetsNavigation() {
        let router = makeRouter(selectedSection: .settings)
        router.settings.push(SettingsRoute.about)

        #expect(
            router.restore(from: Data("not-json".utf8)).result
                == .reset(.corruptData)
        )
        #expect(router.selectedSection == .home)
        #expect(router.settings.path.isEmpty)
    }

    @Test(arguments: [
        (2, Data(#"{"schemaVersion":2,"selectedSection":"settings"}"#.utf8)),
        (3, Data(#"{"schemaVersion":3,"selectedSection":"settings"}"#.utf8)),
        (4, Data(#"{"schemaVersion":4,"selectedSection":"settings"}"#.utf8))
    ])
    func malformedKnownSchemaResetsEveryDurableHistory(
        schemaVersion: Int,
        malformedData: Data
    ) throws {
        let router = makeRouter(selectedSection: .settings)
        router.home.push(HomeRoute.details)
        router.browse.push(BrowseRoute.item(id: "swiftui"))
        router.projects.push(ProjectsRoute.project(id: "project-1"))
        router.settings.push(SettingsRoute.about)

        let restoration = router.restore(from: malformedData)

        #expect(
            try NavigationSnapshotCodec.schemaVersion(in: malformedData)
                == schemaVersion
        )
        #expect(restoration.result == .reset(.corruptData))
        #expect(restoration.lastAppliedTransitionID == nil)
        #expect(router.selectedSection == .home)
        #expect(router.home.path.isEmpty)
        #expect(router.browse.path.isEmpty)
        #expect(router.projects.path.isEmpty)
        #expect(router.settings.path.isEmpty)
    }

    @Test
    func corruptFlowPathResetsOnlyTheAffectedFlow() throws {
        let source = makeRouter(selectedSection: .settings)
        source.home.push(HomeRoute.details)
        source.browse.push(BrowseRoute.item(id: "swiftui"))
        source.settings.push(SettingsRoute.about)
        var snapshot = source.snapshot
        snapshot.settingsPath = FlowPathSnapshot(
            restorationData: Data("not-json".utf8)
        )
        let restored = makeRouter()

        let result = restored.restore(
            from: try NavigationSnapshotCodec.encode(snapshot)
        )

        #expect(result.result == .recovered([.settings]))
        #expect(restored.selectedSection == .settings)
        #expect(restored.home.path.count == 1)
        #expect(restored.browse.path.count == 1)
        #expect(restored.settings.path.isEmpty)
    }

    @Test
    func corruptProjectsPathResetsOnlyProjectsHistory() throws {
        let source = makeRouter(selectedSection: .projects)
        source.home.push(HomeRoute.details)
        source.browse.push(BrowseRoute.item(id: "swiftui"))
        source.settings.push(SettingsRoute.about)
        var snapshot = source.snapshot
        snapshot.projectsPath = FlowPathSnapshot(
            restorationData: Data("not-json".utf8)
        )
        let restored = makeRouter()
        restored.projects.push(ProjectsRoute.project(id: "stale-project"))

        let result = restored.restore(
            from: try NavigationSnapshotCodec.encode(snapshot)
        )

        #expect(result.result == .recovered([.projects]))
        #expect(restored.selectedSection == .projects)
        #expect(restored.home.path.count == 1)
        #expect(restored.browse.path.count == 1)
        #expect(restored.projects.path.isEmpty)
        #expect(restored.settings.path.count == 1)
    }

    @Test
    func snapshotPayloadContainsOnlyDurableNavigationState() throws {
        let router = makeRouter(selectedSection: .projects)
        router.projects.push(ProjectsRoute.project(id: "project-1"))
        let checkpoint = try #require(
            UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        )

        let payload = try #require(
            JSONSerialization.jsonObject(
                with: NavigationSnapshotCodec.encode(
                    router.makeSnapshot(lastAppliedTransitionID: checkpoint)
                )
            ) as? [String: Any]
        )

        #expect(
            Set(payload.keys) == Set([
                "schemaVersion",
                "selectedSection",
                "homePath",
                "browsePath",
                "projectsPath",
                "settingsPath",
                "lastAppliedTransitionID"
            ])
        )
        #expect(
            payload["lastAppliedTransitionID"] as? String
                == "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        )
    }

    @Test
    func futureSchemaResetsMemoryButPreservesStorageAuthority() {
        let future = Data(#"{"schemaVersion":99,"future":"keep"}"#.utf8)
        let router = makeRouter(selectedSection: .settings)
        router.home.push(HomeRoute.details)
        router.settings.push(SettingsRoute.about)

        let restoration = router.restore(from: future)

        #expect(restoration.result == .preservedFutureSchema(99))
        #expect(restoration.lastAppliedTransitionID == nil)
        #expect(router.selectedSection == .home)
        #expect(router.home.path.isEmpty)
        #expect(router.settings.path.isEmpty)
    }

    @Test
    func legacySchemaResetsNavigationAsUnsupported() throws {
        let snapshot = LegacyNavigationSnapshot(
            selectedSection: .browse,
            homePath: [.details],
            browsePath: [.item(id: "swiftui")],
            settingsPath: []
        )
        let router = makeRouter()

        #expect(
            router.restore(from: try JSONEncoder().encode(snapshot)).result
                == .reset(.unsupportedSchema(1))
        )
        #expect(router.selectedSection == .home)
        #expect(router.home.path.isEmpty)
        #expect(router.browse.path.isEmpty)
    }

    @Test
    func authenticationAndPendingIntentAreNotRestored() throws {
        let source = makeRouter(
            flow: .authentication,
            selectedSection: .settings
        )
        source.authentication.push(AuthenticationSnapshotRoute.step)
        _ = source.handle(.browseItem(id: "swiftui"))

        let restoredAppFlowRouter = AppFlowRouter(flow: .main)
        let restored = AppRouter(
            appFlowRouter: restoredAppFlowRouter,
            appFlowCoordinator: AppFlowCoordinatorSpy()
        )
        let data = try NavigationSnapshotCodec.encode(source.snapshot)

        #expect(restored.restore(from: data).result == .restored)
        #expect(restoredAppFlowRouter.flow == .main)
        #expect(restored.selectedSection == .settings)
        #expect(restored.authentication.path.isEmpty)
        #expect(restored.pendingIntent == nil)
    }

    @Test
    func nonCodablePathPersistsAsRecoverableEmptyFlow() throws {
        let source = makeRouter(selectedSection: .home)
        source.home.path.append(NonCodablePathValue(id: "temporary"))
        source.browse.push(BrowseRoute.item(id: "swiftui"))
        let restored = makeRouter()

        let result = restored.restore(
            from: try NavigationSnapshotCodec.encode(source.snapshot)
        )

        #expect(result.result == .recovered([.home]))
        #expect(restored.home.path.isEmpty)
        #expect(restored.browse.path.count == 1)
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

    private func decodeAboutRoute(
        from snapshot: FlowPathSnapshot
    ) throws -> AboutRoute {
        let data = try #require(snapshot.data)
        let pathElements = try JSONDecoder().decode([String].self, from: data)
        let typeIndex = try #require(
            pathElements.firstIndex { $0.hasSuffix(".AboutRoute") }
        )
        let payloadIndex = pathElements.index(after: typeIndex)
        let routePayload = try #require(
            pathElements.dropFirst(payloadIndex).first
        )
        let payload = Data(routePayload.utf8)

        return try JSONDecoder().decode(AboutRoute.self, from: payload)
    }

    private func legacyAboutSettingsPathData(
        platformName: String
    ) throws -> Data {
        let routeData = try JSONSerialization.data(
            withJSONObject: [
                "platform": [
                    "name": platformName
                ]
            ]
        )
        let routePayload = try #require(
            String(data: routeData, encoding: .utf8)
        )

        return try JSONEncoder().encode([
            "AppTemplate.SettingsRoute",
            #""about""#,
            "AppTemplate.AboutRoute",
            routePayload
        ])
    }
}

private
nonisolated
enum AuthenticationSnapshotRoute:
    String,
    NavigationRoute
{
    case step
}

private
nonisolated
struct NonCodablePathValue: Hashable {
    let id: String
}

private
nonisolated
struct LegacyNavigationSnapshot: Encodable {
    let schemaVersion = 1
    let selectedSection: AppSection
    let homePath: [HomeRoute]
    let browsePath: [BrowseRoute]
    let settingsPath: [SettingsRoute]
}
