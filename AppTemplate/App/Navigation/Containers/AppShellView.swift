import SwiftUI

struct AppShellView: View {
    @Bindable var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedSection) {
            Tab("Home", systemImage: "house", value: AppSection.home) {
                HomeFlowView(router: router.home)
            }

            Tab("Browse", systemImage: "square.grid.2x2", value: AppSection.browse) {
                BrowseFlowView(router: router.browse)
            }

            Tab("Projects", systemImage: "folder", value: AppSection.projects) {
                ProjectsFlowView(router: router.projects)
            }

            Tab("Settings", systemImage: "gearshape", value: AppSection.settings) {
                SettingsFlowView(router: router.settings)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
