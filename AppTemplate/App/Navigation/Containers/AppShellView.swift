import SwiftUI

struct AppShellView: View {
    @Bindable var router: AppRouter
    let dependencies: AppDependencies

    var body: some View {
        TabView(selection: $router.selectedSection) {
            Tab("Home", systemImage: "house", value: AppSection.home) {
                HomeFlowView(router: router.home)
            }

            Tab("Browse", systemImage: "square.grid.2x2", value: AppSection.browse) {
                BrowseFlowView(
                    router: router.browse,
                    dependencies: dependencies.browse
                )
            }

            Tab("Projects", systemImage: "folder", value: AppSection.projects) {
                ProjectsFlowView(
                    router: router.projects,
                    dependencies: dependencies.projects
                )
            }

            Tab("Settings", systemImage: "gearshape", value: AppSection.settings) {
                SettingsFlowView(router: router.settings)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
