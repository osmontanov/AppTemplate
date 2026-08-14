import SwiftUI

struct ContentView: View {
    @State private var appFlowCoordinator: AppFlowCoordinator
    @State private var router: AppRouter
    @State private var onboardingRouter: FlowRouter
    @State private var maintenanceRouter: FlowRouter
    let session: SessionPresentation
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport

    init(
        appFlowCoordinator: AppFlowCoordinator,
        session: SessionPresentation,
        storeDependencies: StoreDependencies,
        storeUISupport: StoreUISupport
    ) {
        _appFlowCoordinator = State(initialValue: appFlowCoordinator)
        _router = State(initialValue: AppRouter(appFlowRouter: appFlowCoordinator.appFlowRouter))
        _onboardingRouter = State(initialValue: FlowRouter(appFlowCoordinator: appFlowCoordinator))
        _maintenanceRouter = State(initialValue: FlowRouter(appFlowCoordinator: appFlowCoordinator))
        self.session = session
        self.storeDependencies = storeDependencies
        self.storeUISupport = storeUISupport
    }

    var body: some View {
        AppRootView(
            appFlowRouter: appFlowCoordinator.appFlowRouter,
            router: router,
            onboardingRouter: onboardingRouter,
            maintenanceRouter: maintenanceRouter,
            session: session,
            storeDependencies: storeDependencies,
            storeUISupport: storeUISupport
        )
    }
}

#Preview {
    PreviewFixtures.appComposition(
        state: AppState(hasCompletedOnboarding: true, isMaintenanceEnabled: false),
        isLocalSessionBootstrapResolved: true
    )
}
