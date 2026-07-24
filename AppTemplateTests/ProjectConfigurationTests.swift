import Foundation
import Testing
@testable import AppTemplate

struct ProjectConfigurationTests {
    @Test
    func testTargetLoadsApplicationModule() {
        #expect(Bundle.main.bundleIdentifier == "com.oneday.AppTemplate")
    }

    @MainActor
    @Test
    func navigationRootCanBeConstructed() {
        let router = AppRouter()
        _ = AppRootView(router: router)
        _ = AppShellView(router: router)
    }
}
