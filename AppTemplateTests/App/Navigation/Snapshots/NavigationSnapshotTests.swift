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
    func futureSchemaResetsNavigation() throws {
        let snapshot = NavigationSnapshot(
            schemaVersion: 999,
            selectedSection: .settings,
            homePath: NavigationPath(),
            browsePath: NavigationPath(),
            settingsPath: NavigationPath([SettingsRoute.about])
        )
        let router = AppRouter()

        #expect(
            router.restore(from: try NavigationSnapshotCodec.encode(snapshot))
                == .reset(.unsupportedSchema(999))
        )
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
    func nonCodablePathIsNotPersisted() {
        let router = AppRouter()
        router.home.path.append(NonCodablePathValue(id: "temporary"))

        #expect(
            throws: NavigationSnapshotEncodingError.nonRestorablePath
        ) {
            try NavigationSnapshotCodec.encode(router.snapshot)
        }
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
