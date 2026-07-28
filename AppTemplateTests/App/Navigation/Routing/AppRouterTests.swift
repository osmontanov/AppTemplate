import Testing
@testable import AppTemplate

@MainActor
struct AppRouterTests {
    @Test
    func designatedInitializerKeepsInjectedFeatureRouters() {
        let home = HomeRouter(path: [.details])
        let browse = BrowseRouter(path: [.item(id: "swiftui")])
        let settings = SettingsRouter(path: [.about])

        let router = AppRouter(
            flow: .launching,
            selectedSection: .settings,
            home: home,
            browse: browse,
            settings: settings
        )

        #expect(router.flow == .launching)
        #expect(router.selectedSection == .settings)
        #expect(router.home === home)
        #expect(router.browse === browse)
        #expect(router.settings === settings)
    }

    @Test
    func browseIntentSelectsBrowseAndBuildsPath() {
        let router = AppRouter()
        let outcome = router.handle(.browseItem(id: "swiftui"))

        #expect(outcome == .applied)
        #expect(router.selectedSection == .browse)
        #expect(router.browse.path == [.item(id: "swiftui")])
    }

    @Test
    func unknownBrowseIdentifierStillBuildsTypedRoute() {
        let router = AppRouter(selectedSection: .settings)
        router.home.push(.details)
        router.settings.push(.about)

        let outcome = router.handle(.browseItem(id: "missing"))

        #expect(outcome == .applied)
        #expect(router.selectedSection == .browse)
        #expect(router.browse.path == [.item(id: "missing")])
        #expect(router.home.path == [.details])
        #expect(router.settings.path == [.about])
    }

    @Test
    func intentWaitsForAuthenticationAndReplaysAfterSuccess() {
        let router = AppRouter(flow: .authentication)

        #expect(router.handle(.browseItem(id: "swiftui")) == .deferred)
        #expect(router.pendingIntent == .browseItem(id: "swiftui"))

        #expect(router.completeAuthentication(succeeded: true) == .applied)
        #expect(router.flow == .main)
        #expect(router.pendingIntent == nil)
        #expect(router.browse.path == [.item(id: "swiftui")])
    }

    @Test
    func cancelledAuthenticationClearsPendingIntent() {
        let router = AppRouter(flow: .authentication)
        _ = router.handle(.selectSection(.settings))

        #expect(router.completeAuthentication(succeeded: false) == nil)
        #expect(router.pendingIntent == nil)
        #expect(router.flow == .authentication)
    }

    @Test
    func multipleScenesKeepIndependentRouterState() {
        let firstScene = AppRouter()
        let secondScene = AppRouter()

        _ = firstScene.handle(.browseItem(id: "swiftui"))

        #expect(firstScene.selectedSection == .browse)
        #expect(firstScene.browse.path == [.item(id: "swiftui")])
        #expect(secondScene.selectedSection == .home)
        #expect(secondScene.browse.path.isEmpty)
    }
}
