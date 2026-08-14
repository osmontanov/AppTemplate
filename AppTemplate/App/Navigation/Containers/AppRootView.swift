import SwiftUI

struct AppRootView: View {
    let appFlowRouter: AppFlowRouter
    let router: AppRouter
    let onboardingRouter: FlowRouter
    let maintenanceRouter: FlowRouter
    let session: SessionPresentation
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport

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
                    session: session,
                    storeDependencies: storeDependencies,
                    storeUISupport: storeUISupport
                )
            case .maintenance:
                MaintenanceFlowView(router: maintenanceRouter)
            }
        }
        .id(appFlowRouter.transition.id)
    }
}
