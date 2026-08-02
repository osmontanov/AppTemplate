import Observation
import SwiftUI

@MainActor
@Observable
final class FlowRouter:
    IFlowRouter,
    IAppFlowCoordinator {
    var path: NavigationPath
    private let appFlowCoordinator: any IAppFlowCoordinator

    init(
        path: NavigationPath = NavigationPath(),
        appFlowCoordinator: any IAppFlowCoordinator
    ) {
        self.path = path
        self.appFlowCoordinator = appFlowCoordinator
    }

    @discardableResult
    func completeOnboarding() -> AppFlowActionResult {
        appFlowCoordinator.completeOnboarding()
    }

    @discardableResult
    func restartOnboarding() -> AppFlowActionResult {
        appFlowCoordinator.restartOnboarding()
    }

    @discardableResult
    func signIn() -> AppFlowActionResult {
        appFlowCoordinator.signIn()
    }

    @discardableResult
    func signOut() -> AppFlowActionResult {
        appFlowCoordinator.signOut()
    }

    @discardableResult
    func setMaintenanceEnabled(_ isEnabled: Bool) -> AppFlowActionResult {
        appFlowCoordinator.setMaintenanceEnabled(isEnabled)
    }

    func push<Route: NavigationRoute>(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else {
            return
        }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }

    func replacePath(with path: NavigationPath) {
        self.path = path
    }
}
