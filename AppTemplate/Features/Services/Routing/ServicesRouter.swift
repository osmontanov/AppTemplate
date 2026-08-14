import Observation

@MainActor
@Observable
final class ServicesRouter {
    var path: [ServicesRoute]

    init(path: [ServicesRoute] = []) {
        self.path = path
    }

    func open(_ route: ServicesRoute) { path.append(route) }

    func reset() { path.removeAll() }
}
