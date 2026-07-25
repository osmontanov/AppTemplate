import SwiftUI

struct AppShellView: View {
    @Bindable var router: AppRouter
    let dependencies: AppDependencies

    var body: some View {
        TabView(selection: $router.selectedSection) {
            Tab("Home", systemImage: "house", value: AppSection.home) {
                HomeNavigationView(router: router.home)
            }

            Tab("Browse", systemImage: "square.grid.2x2", value: AppSection.browse) {
                BrowseNavigationView(
                    router: router.browse,
                    repository: dependencies.browseRepository
                )
            }

            Tab("Settings", systemImage: "gearshape", value: AppSection.settings) {
                SettingsNavigationView(router: router.settings)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
