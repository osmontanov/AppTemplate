import Observation
import SwiftUI

@MainActor
@Observable
final class FlowRouter: IFlowRouter {
    var path: NavigationPath

    init(path: NavigationPath = NavigationPath()) {
        self.path = path
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
