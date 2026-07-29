import Foundation
import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct NavigationSnapshotTests {
    @Test
    func mixedScreenRoutePathRoundTripsThroughJSON() throws {
        let source = AppRouter(selectedSection: .home)
        source.home.push(HomeRoute.details)
        source.home.push(HomeDetailsRoute.navigationGuide)

        let data = try NavigationSnapshotCodec.encode(source.snapshot)
        let restored = AppRouter()

        #expect(restored.restore(from: data) == .restored)
        #expect(restored.home.path.count == 2)
        #expect(restored.snapshot == source.snapshot)
    }

    @Test
    func projectsScreenRoutePathRoundTripsThroughJSON() throws {
        let source = AppRouter(selectedSection: .projects)
        source.projects.push(ProjectsRoute.project(id: "project-1"))
        source.projects.push(
            ProjectDetailsRoute.task(
                projectID: "project-1",
                taskID: "task-1"
            )
        )
        let data = try NavigationSnapshotCodec.encode(source.snapshot)
        let restored = AppRouter()

        #expect(restored.restore(from: data) == .restored)
        #expect(restored.projects.path.count == 2)
    }

    @Test
    func schemaTwoSnapshotMigratesItsDurableHistories() throws {
        let legacy = NavigationSnapshotV2(
            selectedSection: .browse,
            homePath: FlowPathSnapshot(
                path: NavigationPath([HomeRoute.details])
            ),
            browsePath: FlowPathSnapshot(
                path: NavigationPath([BrowseRoute.item(id: "swiftui")])
            ),
            settingsPath: FlowPathSnapshot(path: NavigationPath())
        )
        let restored = AppRouter()

        #expect(
            restored.restore(from: try JSONEncoder().encode(legacy))
                == .migrated(from: 2)
        )
        #expect(restored.home.path.count == 1)
        #expect(restored.browse.path.count == 1)
        #expect(restored.projects.path.isEmpty)
    }

    @Test
    func unchangedSnapshotDoesNotRequestAnotherEncoding() throws {
        let router = AppRouter()
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
    func changedSnapshotProducesReplacementEncoding() throws {
        let storedRouter = AppRouter()
        let changedRouter = AppRouter(selectedSection: .browse)
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
        let source = AppRouter(selectedSection: .browse)
        source.home.push(HomeRoute.details)
        source.browse.push(BrowseRoute.item(id: "swiftui"))
        source.browse.push(BrowseRoute.item(id: "deleted"))
        source.settings.push(SettingsRoute.about)
        let restored = AppRouter()

        let result = restored.restore(
            from: try NavigationSnapshotCodec.encode(source.snapshot)
        )

        #expect(result == .restored)
        #expect(restored.snapshot == source.snapshot)
        #expect(restored.browse.path.count == 2)
    }

    @Test
    func corruptDataResetsNavigation() {
        let router = AppRouter(selectedSection: .settings)
        router.settings.push(SettingsRoute.about)

        #expect(
            router.restore(from: Data("not-json".utf8))
                == .reset(.corruptData)
        )
        #expect(router.selectedSection == .home)
        #expect(router.settings.path.isEmpty)
    }

    @Test
    func corruptFlowPathResetsOnlyTheAffectedFlow() throws {
        let source = AppRouter(selectedSection: .settings)
        source.home.push(HomeRoute.details)
        source.browse.push(BrowseRoute.item(id: "swiftui"))
        source.settings.push(SettingsRoute.about)
        var snapshot = source.snapshot
        snapshot.settingsPath = FlowPathSnapshot(
            restorationData: Data("not-json".utf8)
        )
        let restored = AppRouter()

        let result = restored.restore(
            from: try NavigationSnapshotCodec.encode(snapshot)
        )

        #expect(result == .recovered([.settings]))
        #expect(restored.selectedSection == .settings)
        #expect(restored.home.path.count == 1)
        #expect(restored.browse.path.count == 1)
        #expect(restored.settings.path.isEmpty)
    }

    @Test
    func corruptProjectsPathResetsOnlyProjectsHistory() throws {
        let source = AppRouter(selectedSection: .projects)
        source.home.push(HomeRoute.details)
        source.browse.push(BrowseRoute.item(id: "swiftui"))
        source.settings.push(SettingsRoute.about)
        var snapshot = source.snapshot
        snapshot.projectsPath = FlowPathSnapshot(
            restorationData: Data("not-json".utf8)
        )
        let restored = AppRouter()
        restored.projects.push(ProjectsRoute.project(id: "stale-project"))

        let result = restored.restore(
            from: try NavigationSnapshotCodec.encode(snapshot)
        )

        #expect(result == .recovered([.projects]))
        #expect(restored.selectedSection == .projects)
        #expect(restored.home.path.count == 1)
        #expect(restored.browse.path.count == 1)
        #expect(restored.projects.path.isEmpty)
        #expect(restored.settings.path.count == 1)
    }

    @Test
    func snapshotIncludesProjectsPathButExcludesTransientSheetAndDraftState() throws {
        let router = AppRouter(selectedSection: .projects)
        router.projects.push(ProjectsRoute.project(id: "project-1"))

        let json = String(
            decoding: try NavigationSnapshotCodec.encode(router.snapshot),
            as: UTF8.self
        )

        #expect(json.contains("projectsPath"))
        for transientName in [
            "quickStart",
            "options",
            "sessionInfo",
            "createProject",
            "projectInfo",
            "title",
            "summary",
            "colorName"
        ] {
            #expect(!json.contains(transientName))
        }
    }

    @Test
    func futureSchemaResetsNavigation() throws {
        let snapshot = NavigationSnapshot(
            schemaVersion: 999,
            selectedSection: .settings,
            homePath: NavigationPath(),
            browsePath: NavigationPath(),
            projectsPath: NavigationPath(),
            settingsPath: NavigationPath([SettingsRoute.about])
        )
        let router = AppRouter()

        #expect(
            router.restore(from: try NavigationSnapshotCodec.encode(snapshot))
                == .reset(.unsupportedSchema(999))
        )
    }

    @Test
    func legacySchemaResetsNavigationAsUnsupported() throws {
        let snapshot = LegacyNavigationSnapshot(
            selectedSection: .browse,
            homePath: [.details],
            browsePath: [.item(id: "swiftui")],
            settingsPath: []
        )
        let router = AppRouter()

        #expect(
            router.restore(from: try JSONEncoder().encode(snapshot))
                == .reset(.unsupportedSchema(1))
        )
        #expect(router.selectedSection == .home)
        #expect(router.home.path.isEmpty)
        #expect(router.browse.path.isEmpty)
    }

    @Test
    func authenticationAndPendingIntentAreNotRestored() throws {
        let source = AppRouter(
            flow: .authentication,
            selectedSection: .settings
        )
        source.authentication.push(AuthenticationSnapshotRoute.step)
        _ = source.handle(.browseItem(id: "swiftui"))

        let restored = AppRouter()
        let data = try NavigationSnapshotCodec.encode(source.snapshot)

        #expect(restored.restore(from: data) == .restored)
        #expect(restored.flow == .main)
        #expect(restored.selectedSection == .settings)
        #expect(restored.authentication.path.isEmpty)
        #expect(restored.pendingIntent == nil)
    }

    @Test
    func nonCodablePathPersistsAsRecoverableEmptyFlow() throws {
        let source = AppRouter(selectedSection: .home)
        source.home.path.append(NonCodablePathValue(id: "temporary"))
        source.browse.push(BrowseRoute.item(id: "swiftui"))
        let restored = AppRouter()

        let result = restored.restore(
            from: try NavigationSnapshotCodec.encode(source.snapshot)
        )

        #expect(result == .recovered([.home]))
        #expect(restored.home.path.isEmpty)
        #expect(restored.browse.path.count == 1)
    }
}

private nonisolated enum AuthenticationSnapshotRoute:
    String,
    NavigationRoute
{
    case step
}

private nonisolated struct NonCodablePathValue: Hashable {
    let id: String
}

private nonisolated struct LegacyNavigationSnapshot: Encodable {
    let schemaVersion = 1
    let selectedSection: AppSection
    let homePath: [HomeRoute]
    let browsePath: [BrowseRoute]
    let settingsPath: [SettingsRoute]
}

private nonisolated struct NavigationSnapshotV2: Encodable {
    let schemaVersion = 2
    let selectedSection: AppSection
    let homePath: FlowPathSnapshot
    let browsePath: FlowPathSnapshot
    let settingsPath: FlowPathSnapshot
}
