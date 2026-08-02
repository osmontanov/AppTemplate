import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let router: any IFlowRouter
    private let authenticationActions: any IAuthenticationActions
    let model: SettingsModel
    var sheet: SettingsSheetRoute?

    init(
        router: any IFlowRouter,
        authenticationActions: any IAuthenticationActions,
        appInfo: any IAppInfoService
    ) {
        self.router = router
        self.authenticationActions = authenticationActions
        model = SettingsModel(
            displayName: appInfo.displayName,
            version: appInfo.version
        )
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
