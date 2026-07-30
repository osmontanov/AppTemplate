import Observation
import SwiftUI

@MainActor
@Observable
final class FlowRouter: IRouter {
    var path: NavigationPath
    private let appFlowCoordinator: any IAppFlowCoordinator

    init(
        path: NavigationPath = NavigationPath(),
        appFlowCoordinator: any IAppFlowCoordinator
    ) {
        self.path = path
        self.appFlowCoordinator = appFlowCoordinator
    }

    func setFlow(_ flow: AppFlow) {
        appFlowCoordinator.setFlow(flow)
    }

    func completeOnboarding() {
        appFlowCoordinator.completeOnboarding()
    }

    func restartOnboarding() {
        appFlowCoordinator.restartOnboarding()
    }

    func signIn() {
        appFlowCoordinator.signIn()
    }

    func signOut() {
        appFlowCoordinator.signOut()
    }

    func setMaintenanceEnabled(_ isEnabled: Bool) {
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
