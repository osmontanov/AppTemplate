import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let router: any IFlowRouter
    private let authenticationActions: any IAuthenticationActions
    var sheet: SettingsSheetRoute?

    init(
        router: any IFlowRouter,
        authenticationActions: any IAuthenticationActions
    ) {
        self.router = router
        self.authenticationActions = authenticationActions
    }

    func openAbout() {
        router.push(SettingsRoute.about)
    }

    func openSessionInfo() {
        sheet = .sessionInfo
    }

    func dismissSheet() {
        sheet = nil
    }

    func returnToAuthentication() {
        authenticationActions.signOut()
    }
}
