import SwiftUI

struct AppSectionContentView: View {
    let section: AppSection
    let storeRouter: StoreRouter
    let servicesRouter: ServicesRouter
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport
    let storeCatalogViewModel: CatalogViewModel
    let servicesDependencies: ServicesDependencies
    let sceneNavigation: any ISceneNavigationActions
    private let storeNavigationIsActive: @MainActor () -> Bool
    private let servicesNavigationIsActive: @MainActor () -> Bool

    init(
        section: AppSection,
        storeRouter: StoreRouter,
        servicesRouter: ServicesRouter,
        storeDependencies: StoreDependencies,
        storeUISupport: StoreUISupport,
        storeCatalogViewModel: CatalogViewModel,
        servicesDependencies: ServicesDependencies,
        sceneNavigation: any ISceneNavigationActions,
        storeNavigationIsActive: @escaping @MainActor () -> Bool = { true },
        servicesNavigationIsActive: @escaping @MainActor () -> Bool = { true }
    ) {
        self.section = section
        self.storeRouter = storeRouter
        self.servicesRouter = servicesRouter
        self.storeDependencies = storeDependencies
        self.storeUISupport = storeUISupport
        self.storeCatalogViewModel = storeCatalogViewModel
        self.servicesDependencies = servicesDependencies
        self.sceneNavigation = sceneNavigation
        self.storeNavigationIsActive = storeNavigationIsActive
        self.servicesNavigationIsActive = servicesNavigationIsActive
    }

    var body: some View {
        switch section {
        case .store:
            StoreFlowView(
                router: storeRouter,
                dependencies: storeDependencies,
                uiSupport: storeUISupport,
                catalogViewModel: storeCatalogViewModel,
                acceptsNavigationPathUpdates: storeNavigationIsActive
            )
        case .services:
            ServicesFlowView(
                router: servicesRouter,
                dependencies: servicesDependencies,
                sceneNavigation: sceneNavigation,
                acceptsNavigationPathUpdates: servicesNavigationIsActive
            )
        }
    }
}
