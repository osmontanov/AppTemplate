import SwiftUI

struct AppRootView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Bindable var router: AppRouter
    let dependencies: AppDependencies

    var body: some View {
        switch router.flow {
        case .launching:
            ProgressView("Launching…")
        case .authentication:
            AuthenticationFlowView(
                router: router.authentication,
                sessionStore: sessionStore,
                appRouter: router
            )
        case .main:
            AppShellView(router: router, dependencies: dependencies)
        }
    }
}
