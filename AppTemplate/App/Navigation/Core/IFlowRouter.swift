@MainActor
protocol IFlowRouter: AnyObject {
    func push<Route: NavigationRoute>(_ route: Route)
    func pop()
    func popToRoot()
}
