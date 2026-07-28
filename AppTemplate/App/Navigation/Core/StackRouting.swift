import Foundation

@MainActor
protocol StackRouting: AnyObject {
    associatedtype Route: Hashable & Codable
    var path: [Route] { get set }
}

extension StackRouting {
    func push(_ route: Route) {
        path.append(route)
    }

    @discardableResult
    func pop() -> Route? {
        path.popLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    func replacePath(with routes: [Route]) {
        path = routes
    }
}
