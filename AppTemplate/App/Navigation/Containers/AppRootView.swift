import SwiftUI

struct AppRootView: View {
    let appFlowRouter: AppFlowRouter
    let router: AppRouter
    let dependencies: AppDependencies

    var body: some View {
        Group {
            switch appFlowRouter.flow {
            case .authentication:
                AuthenticationFlowView(router: router.authentication)
            case .onboarding:
                OnboardingFlowView(router: router.onboarding)
            case .main:
                AppShellView(router: router, dependencies: dependencies)
            case .maintenance:
                MaintenanceFlowView(router: router.maintenance)
            }
        }
        .id(appFlowRouter.transition.id)
    }
}
