import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct AppSceneNavigationLifecycleTests {
    @Test
    func coldLaunchURLsApplyInArrivalOrderAfterRestoration() throws {
        let router = AppRouter()
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        let storedSnapshot = NavigationSnapshot(
            selectedSection: .home,
            homePath: [.details],
            browsePath: [],
            settingsPath: []
        )

        lifecycle.receive(try #require(URL(string: "apptemplate://browse/item/swiftui")))
        lifecycle.receive(try #require(URL(string: "apptemplate://settings")))
        let snapshotToPersist = lifecycle.restore(
            from: try NavigationSnapshotCodec.encode(storedSnapshot)
        )

        #expect(router.selectedSection == .settings)
        #expect(router.home.path == [.details])
        #expect(router.browse.path == [.item(id: "swiftui")])
        #expect(snapshotToPersist == router.snapshot)
    }

    @Test
    func invalidColdLaunchURLResetsRestoredNavigation() throws {
        let router = AppRouter()
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        let storedSnapshot = NavigationSnapshot(
            selectedSection: .settings,
            homePath: [.details],
            browsePath: [.item(id: "swiftui")],
            settingsPath: [.about]
        )

        lifecycle.receive(try #require(URL(string: "apptemplate://unknown")))
        let snapshotToPersist = lifecycle.restore(
            from: try NavigationSnapshotCodec.encode(storedSnapshot)
        )

        #expect(router.snapshot == NavigationSnapshot(
            selectedSection: .home,
            homePath: [],
            browsePath: [],
            settingsPath: []
        ))
        #expect(snapshotToPersist == router.snapshot)
    }

    @Test
    func authenticationGatedColdLaunchIntentRemainsPending() throws {
        let router = AppRouter(flow: .authentication)
        let lifecycle = AppSceneNavigationLifecycle(router: router)

        lifecycle.receive(try #require(URL(string: "apptemplate://browse/item/swiftui")))
        _ = lifecycle.restore(from: nil)

        #expect(router.pendingIntent == .browseItem(id: "swiftui"))
        #expect(router.selectedSection == .home)
    }
}
