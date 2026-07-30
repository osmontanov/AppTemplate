import Observation
import SwiftUI

@MainActor
@Observable
final class FlowRouter: IRouter {
    var path: NavigationPath
    private let appFlowRouter: any IAppFlowRouter

    init(
        path: NavigationPath = NavigationPath(),
        appFlowRouter: (any IAppFlowRouter)? = nil
    ) {
        self.path = path
        self.appFlowRouter = appFlowRouter ?? AppFlowRouter(flow: .main)
    }

    func setFlow(_ flow: AppFlow) {
        appFlowRouter.setFlow(flow)
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
