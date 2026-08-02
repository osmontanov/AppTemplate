import SwiftUI

struct AppRootView: View {
    let appFlowRouter: AppFlowRouter
    let router: AppRouter

    var body: some View {
        Group {
            switch appFlowRouter.flow {
            case .authentication:
                AuthenticationFlowView(
                    router: router.authentication,
                    authenticationCancellation: router
                )
            case .onboarding:
                OnboardingFlowView(router: router.onboarding)
            case .main:
                AppShellView(router: router)
            case .maintenance:
                MaintenanceFlowView(router: router.maintenance)
            }
        }
        .id(appFlowRouter.transition.id)
    }
}
