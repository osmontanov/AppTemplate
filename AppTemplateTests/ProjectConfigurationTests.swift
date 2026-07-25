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
        let dependencies = AppDependencies.preview(
            browseItems: [],
            session: nil
        )

        _ = AppSceneView(dependencies: dependencies)
        _ = AppRootView(router: router, dependencies: dependencies)
        _ = AppShellView(router: router, dependencies: dependencies)
        _ = BrowseNavigationView(
            router: router.browse,
            repository: dependencies.browseRepository
        )
    }
}

extension ProjectConfigurationTests {
    @Test
    func applicationRegistersCustomURLScheme() throws {
        let urlTypes = try #require(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes")
                as? [[String: Any]]
        )
        let schemes = urlTypes
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .flatMap { $0 }

        #expect(schemes.contains("apptemplate"))
    }
}
