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
    func unknownColdLaunchURLFallsBackToHomeAndPreservesOtherHistories() throws {
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
            browsePath: [.item(id: "swiftui")],
            settingsPath: [.about]
        ))
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
        router.home.push(.details)
        router.browse.push(.item(id: "swiftui"))
        router.settings.push(.about)

        _ = lifecycle.receive(try #require(URL(string: rawURL)))

        #expect(router.selectedSection == expectedSection)
        #expect(router.home.path == (expectedSection == .home ? [] : [.details]))
        #expect(router.browse.path == (
            expectedSection == .browse ? [] : [.item(id: "swiftui")]
        ))
        #expect(router.settings.path == (expectedSection == .settings ? [] : [.about]))
    }

    @Test
    func unknownBrowseRecordColdLaunchKeepsRouteAndOtherHistories() throws {
        let router = AppRouter()
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        let storedSnapshot = NavigationSnapshot(
            selectedSection: .settings,
            homePath: [.details],
            browsePath: [.item(id: "swiftui")],
            settingsPath: [.about]
        )

        lifecycle.receive(try #require(URL(string: "apptemplate://browse/item/deleted")))
        let snapshotToPersist = lifecycle.restore(
            from: try NavigationSnapshotCodec.encode(storedSnapshot)
        )

        #expect(router.selectedSection == .browse)
        #expect(router.home.path == [.details])
        #expect(router.browse.path == [.item(id: "deleted")])
        #expect(router.settings.path == [.about])
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

    @Test
    func invalidURLAfterValidURLWinsAuthenticationQueueWithoutErasingOtherHistories() throws {
        let router = AppRouter(flow: .authentication)
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        _ = lifecycle.restore(from: nil)
        router.home.push(.details)
        router.browse.push(.item(id: "observation"))
        router.settings.push(.about)

        lifecycle.receive(try #require(URL(string: "apptemplate://browse/item/swiftui")))
        lifecycle.receive(try #require(URL(string: "apptemplate://settings/not-a-route")))
        let outcome = router.completeAuthentication(succeeded: true)

        #expect(outcome == .applied)
        #expect(router.selectedSection == .settings)
        #expect(router.home.path == [.details])
        #expect(router.browse.path == [.item(id: "observation")])
        #expect(router.settings.path.isEmpty)
    }

    @Test
    func validURLAfterInvalidURLWinsAuthenticationQueueWithoutApplyingOlderFallback() throws {
        let router = AppRouter(flow: .authentication)
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        _ = lifecycle.restore(from: nil)
        router.home.push(.details)
        router.browse.push(.item(id: "observation"))
        router.settings.push(.about)

        lifecycle.receive(try #require(URL(string: "apptemplate://settings/not-a-route")))
        lifecycle.receive(try #require(URL(string: "apptemplate://browse/item/swiftui")))
        let outcome = router.completeAuthentication(succeeded: true)

        #expect(outcome == .applied)
        #expect(router.selectedSection == .browse)
        #expect(router.home.path == [.details])
        #expect(router.browse.path == [.item(id: "swiftui")])
        #expect(router.settings.path == [.about])
    }
}
