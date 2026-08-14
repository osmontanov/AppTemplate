import SwiftUI

struct AppRootView: View {
    let appFlowRouter: AppFlowRouter
    let router: AppRouter
    let onboardingRouter: FlowRouter
    let maintenanceRouter: FlowRouter
    let session: SessionPresentation

    var body: some View {
        Group {
            switch appFlowRouter.flow {
            case .restoring:
                SessionRestoringView()
            case .onboarding:
                OnboardingFlowView(router: onboardingRouter)
            case .main:
                AppShellView(router: router, session: session)
            case .maintenance:
                MaintenanceFlowView(router: maintenanceRouter)
            }
        }
        .id(appFlowRouter.transition.id)
    }
}
