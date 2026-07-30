import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let router: any IRouter
    var sheet: SettingsSheetRoute?

    init(router: any IRouter) {
        self.router = router
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
        router.setFlow(.authentication)
    }
}
