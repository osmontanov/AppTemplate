import Observation

@MainActor
@Observable
final class BrowseRouter: StackRouting {
    var path: [BrowseRoute]

    init(path: [BrowseRoute] = []) {
        self.path = path
    }
}
