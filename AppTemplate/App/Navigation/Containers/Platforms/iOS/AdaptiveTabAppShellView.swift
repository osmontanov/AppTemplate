#if os(iOS)
import SwiftUI

struct AdaptiveTabAppShellView: View {
    @Bindable var router: AppRouter
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport
    let storeCatalogViewModel: CatalogViewModel
    let servicesDependencies: ServicesDependencies
    let sceneNavigation: any ISceneNavigationActions

    var body: some View {
        TabView(selection: $router.selectedSection) {
            ForEach(AppSection.allCases) { section in
                Tab(section.localizedTitle, systemImage: section.systemImage, value: section) {
                    AppSectionContentView(
                        section: section,
                        storeRouter: router.store,
                        servicesRouter: router.services,
                        storeDependencies: storeDependencies,
                        storeUISupport: storeUISupport,
                        storeCatalogViewModel: storeCatalogViewModel,
                        servicesDependencies: servicesDependencies,
                        sceneNavigation: sceneNavigation
                    )
                    .background {
                        TabAccessibilityIdentifierInstaller()
                            .frame(width: 0, height: 0)
                            .accessibilityHidden(true)
                    }
                }
                .customizationID(section.presentationIdentifier)
                .accessibilityLabel(section.localizedTitle)
                .accessibilityValue(
                    router.selectedSection == section
                        ? StoreServicesText.resource("Selected")
                        : StoreServicesText.resource("Not selected")
                )
                .accessibilityIdentifier(section.accessibilityIdentifier)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
#endif
