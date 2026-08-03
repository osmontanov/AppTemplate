import SwiftUI

struct AppSectionContentView: View {
    let section: AppSection
    let router: AppRouter
    let settings: SettingsDependencies

    var body: some View {
        switch section {
        case .home:
            HomeFlowView(router: router.home)
        case .browse:
            BrowseFlowView(router: router.browse)
        case .projects:
            ProjectsFlowView(router: router.projects)
        case .settings:
            SettingsFlowView(
                router: router.settings,
                dependencies: settings
            )
        }
    }
}
