#if os(macOS)
import SwiftUI

struct MacSidebarAppShellView: View {
    @Bindable var router: AppRouter
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport
    let storeCatalogViewModel: CatalogViewModel
    let servicesDependencies: ServicesDependencies
    let sceneNavigation: any ISceneNavigationActions

    var body: some View {
        NavigationSplitView {
            List(selection: $router.selectedSection) {
                ForEach(AppSection.allCases) { section in
                    Label(section.localizedTitle, systemImage: section.systemImage)
                        .accessibilityValue(
                            router.selectedSection == section
                                ? AppText.resource("Selected")
                                : AppText.resource("Not selected")
                        )
                        .accessibilityIdentifier(section.accessibilityIdentifier)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
        } detail: {
            AppSectionContentView(
                section: router.selectedSection,
                storeRouter: router.store,
                servicesRouter: router.services,
                storeDependencies: storeDependencies,
                storeUISupport: storeUISupport,
                storeCatalogViewModel: storeCatalogViewModel,
                servicesDependencies: servicesDependencies,
                sceneNavigation: sceneNavigation,
                storeNavigationIsActive: { router.selectedSection == .store },
                servicesNavigationIsActive: { router.selectedSection == .services }
            )
        }
        .frame(minWidth: 820, minHeight: 620)
    }
}
#endif
