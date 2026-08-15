import SwiftUI

struct AppRootView: View {
    let appFlowRouter: AppFlowRouter
    let router: AppRouter
    let onboardingRouter: FlowRouter
    let maintenanceRouter: FlowRouter
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport
    let storeCatalogViewModel: CatalogViewModel
    let servicesDependencies: ServicesDependencies
    let sceneNavigation: any ISceneNavigationActions

    var body: some View {
        Group {
            switch appFlowRouter.flow {
            case .restoring:
                SessionRestoringView()
            case .onboarding:
                OnboardingFlowView(router: onboardingRouter)
            case .main:
                AppShellView(
                    router: router,
                    storeDependencies: storeDependencies,
                    storeUISupport: storeUISupport,
                    storeCatalogViewModel: storeCatalogViewModel,
                    servicesDependencies: servicesDependencies,
                    sceneNavigation: sceneNavigation
                )
            case .maintenance:
                MaintenanceFlowView(router: maintenanceRouter)
            }
        }
        .id(appFlowRouter.transition.id)
    }
}
