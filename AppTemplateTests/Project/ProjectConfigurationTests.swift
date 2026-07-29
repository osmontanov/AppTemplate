import Foundation
import SwiftUI
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
        let sessionStore = SessionStore(service: dependencies.session.service)

        _ = AppSceneView(dependencies: dependencies)
            .environment(sessionStore)
        _ = AppRootView(router: router, dependencies: dependencies)
            .environment(sessionStore)
        _ = AppShellView(router: router, dependencies: dependencies)
            .environment(sessionStore)
        _ = AuthenticationFlowView(
            router: router.authentication,
            sessionStore: sessionStore,
            appRouter: router
        )
        _ = HomeFlowView(router: router.home)
        _ = BrowseFlowView(
            router: router.browse,
            dependencies: dependencies.browse
        )
        _ = ProjectsFlowView(
            router: router.projects,
            dependencies: dependencies.projects
        )
        let projectsStore = ProjectsStore()
        let draft = CreateProjectDraftState()
        _ = CreateProjectFlowView(
            store: projectsStore
        )
        _ = ProjectInfoView(
            projectID: "project-1",
            store: projectsStore
        )
        _ = ProjectInfoView(
            projectID: "missing",
            store: ProjectsStore(projects: [])
        )
        _ = ProjectBasicsView(
            draft: draft,
            router: FlowRouter(),
            store: projectsStore
        )
        _ = ProjectOptionsView(
            draft: draft,
            router: FlowRouter(),
            store: projectsStore
        )
        _ = ProjectReviewView(
            draft: draft,
            store: projectsStore
        )
        _ = SettingsFlowView(
            router: router.settings,
            sessionStore: sessionStore
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
