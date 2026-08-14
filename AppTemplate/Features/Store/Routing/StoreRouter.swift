import Observation

@MainActor
@Observable
final class StoreRouter {
    var path: [StoreRoute]
    var presentation: StorePresentation?

    init(path: [StoreRoute] = []) {
        self.path = path
    }

    func push(_ route: StoreRoute) { path.append(route) }

    func replace(with route: StoreRoute) { path = [route] }

    func reset() {
        path.removeAll()
        presentation = nil
    }
}
