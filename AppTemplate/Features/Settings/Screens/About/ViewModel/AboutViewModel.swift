import Observation

@MainActor
@Observable
final class AboutViewModel {
    private let router: any IFlowRouter
    let supportedPlatforms = [
        "iOS 26",
        "iPadOS 26",
        "macOS 26"
    ]
    let exampleDescription =
        "Home, Browse, Projects, and Settings are replaceable feature examples."

    init(router: any IFlowRouter) {
        self.router = router
    }

    func openPlatform(name: String) {
        router.push(AboutRoute.platform(name: name))
    }
}
