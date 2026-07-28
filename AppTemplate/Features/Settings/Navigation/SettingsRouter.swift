import Observation

@MainActor
@Observable
final class SettingsRouter: StackRouting {
    var path: [SettingsRoute]

    init(path: [SettingsRoute] = []) {
        self.path = path
    }
}
