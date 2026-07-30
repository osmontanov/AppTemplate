import SwiftUI

struct AppRootView: View {
    @Environment(SessionStore.self) private var sessionStore
    let appFlowRouter: AppFlowRouter
    let router: AppRouter
    let dependencies: AppDependencies

    var body: some View {
        Group {
            switch appFlowRouter.flow {
            case .launching:
                ProgressView("Launching…")
            case .authentication:
                AuthenticationFlowView(
                    router: router.authentication,
                    sessionStore: sessionStore
                )
            case .main:
                AppShellView(router: router, dependencies: dependencies)
            }
        }
        .id(appFlowRouter.transition.id)
    }
}
