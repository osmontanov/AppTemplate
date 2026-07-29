import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct AppRouterTests {
    @Test
    func designatedInitializerKeepsInjectedFlowRouters() {
        let authentication = FlowRouter()
        let home = FlowRouter()
        let browse = FlowRouter()
        let settings = FlowRouter()

        let router = AppRouter(
            flow: .launching,
            selectedSection: .settings,
            authentication: authentication,
            home: home,
            browse: browse,
            settings: settings
        )

        #expect(router.flow == .launching)
        #expect(router.selectedSection == .settings)
        #expect(router.authentication === authentication)
        #expect(router.home === home)
        #expect(router.browse === browse)
        #expect(router.settings === settings)
    }

    @Test
    func browseIntentSelectsBrowseAndBuildsCanonicalPath() {
        let router = AppRouter()

        let outcome = router.handle(.browseItem(id: "swiftui"))

        #expect(outcome == .applied)
        #expect(router.selectedSection == .browse)
        #expect(router.browse.path.count == 1)
    }

    @Test
    func unknownBrowseIdentifierStillBuildsRouteAndPreservesOtherFlows() {
        let router = AppRouter(selectedSection: .settings)
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
    func successfulNewAuthenticationResetsHistoriesBeforeReplayingIntent() {
        let router = AppRouter(flow: .authentication)
        router.authentication.push(AuthenticationTestRoute.step)
        router.home.push(HomeRoute.details)
        router.settings.push(SettingsRoute.about)
        _ = router.handle(.browseItem(id: "swiftui"))

        let outcome = router.completeAuthentication(succeeded: true)

        #expect(outcome == .applied)
        #expect(router.flow == .main)
        #expect(router.pendingIntent == nil)
        #expect(router.authentication.path.isEmpty)
        #expect(router.home.path.isEmpty)
        #expect(router.settings.path.isEmpty)
        #expect(router.browse.path.count == 1)
        #expect(router.selectedSection == .browse)
    }

    @Test
    func cancelledAuthenticationClearsPendingIntentAndAuthenticationHistory() {
        let router = AppRouter(flow: .authentication)
        router.authentication.push(AuthenticationTestRoute.step)
        _ = router.handle(.selectSection(.settings))

        #expect(router.completeAuthentication(succeeded: false) == nil)
        #expect(router.pendingIntent == nil)
        #expect(router.flow == .authentication)
        #expect(router.authentication.path.isEmpty)
    }

    @Test
    func authenticatedColdLaunchPreservesRestoredTabHistories() {
        let router = AppRouter(flow: .launching)
        router.home.push(HomeRoute.details)
        router.authentication.push(AuthenticationTestRoute.step)

        _ = router.finishLaunching(isAuthenticated: true)

        #expect(router.flow == .main)
        #expect(router.home.path.count == 1)
        #expect(router.authentication.path.isEmpty)
    }

    @Test
    func requiringAuthenticationResetsEveryHistory() {
        let router = AppRouter()
        router.home.push(HomeRoute.details)
        router.browse.push(BrowseRoute.item(id: "swiftui"))
        router.settings.push(SettingsRoute.about)

        router.requireAuthentication()

        #expect(router.flow == .authentication)
        #expect(router.selectedSection == .home)
        #expect(router.authentication.path.isEmpty)
        #expect(router.home.path.isEmpty)
        #expect(router.browse.path.isEmpty)
        #expect(router.settings.path.isEmpty)
    }

    @Test
    func multipleScenesKeepIndependentRouterState() {
        let firstScene = AppRouter()
        let secondScene = AppRouter()

        _ = firstScene.handle(.browseItem(id: "swiftui"))

        #expect(firstScene.selectedSection == .browse)
        #expect(firstScene.browse.path.count == 1)
        #expect(secondScene.selectedSection == .home)
        #expect(secondScene.browse.path.isEmpty)
    }
}

private nonisolated enum AuthenticationTestRoute: String, NavigationRoute {
    case step
}
