import SwiftUI

struct ContentView: View {
    @State private var appFlowCoordinator: AppFlowCoordinator
    @State private var router: AppRouter
    @State private var sceneNavigation: AppSceneNavigationLifecycle
    @State private var onboardingRouter: FlowRouter
    @State private var maintenanceRouter: FlowRouter
    @State private var storeCatalogViewModel: CatalogViewModel
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport
    let servicesDependencies: ServicesDependencies

    init(
        appFlowCoordinator: AppFlowCoordinator,
        storeDependencies: StoreDependencies,
        storeUISupport: StoreUISupport,
        servicesDependencies: ServicesDependencies
    ) {
        _appFlowCoordinator = State(initialValue: appFlowCoordinator)
        let router = AppRouter(appFlowRouter: appFlowCoordinator.appFlowRouter)
        _router = State(initialValue: router)
        _sceneNavigation = State(
            initialValue: AppSceneNavigationLifecycle(router: router)
        )
        _onboardingRouter = State(initialValue: FlowRouter(appFlowCoordinator: appFlowCoordinator))
        _maintenanceRouter = State(initialValue: FlowRouter(appFlowCoordinator: appFlowCoordinator))
        _storeCatalogViewModel = State(initialValue: CatalogViewModel(
            products: storeDependencies.products,
            preferences: storeDependencies.preferences,
            clock: storeUISupport.clock
        ))
        self.storeDependencies = storeDependencies
        self.storeUISupport = storeUISupport
        self.servicesDependencies = servicesDependencies
    }

    var body: some View {
        AppRootView(
            appFlowRouter: appFlowCoordinator.appFlowRouter,
            router: router,
            onboardingRouter: onboardingRouter,
            maintenanceRouter: maintenanceRouter,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport,
            storeCatalogViewModel: storeCatalogViewModel,
            servicesDependencies: servicesDependencies,
            sceneNavigation: sceneNavigation
        )
    }
}

#Preview {
    PreviewFixtures.appComposition(
        state: AppState(hasCompletedOnboarding: true, isMaintenanceEnabled: false),
        isLocalSessionBootstrapResolved: true
    )
}
