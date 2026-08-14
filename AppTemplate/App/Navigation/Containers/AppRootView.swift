import SwiftUI

struct AppRootView: View {
    let appFlowRouter: AppFlowRouter
    let router: AppRouter
    let settings: SettingsDependencies

    var body: some View {
        Group {
            switch appFlowRouter.flow {
            case .restoring:
                SessionRestoringView()
            case .onboarding:
                OnboardingFlowView(router: router.onboarding)
            case .main:
                AppShellView(router: router, settings: settings)
            case .maintenance:
                MaintenanceFlowView(router: router.maintenance)
            }
        }
        .id(appFlowRouter.transition.id)
    }
}
