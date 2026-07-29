import Observation

@MainActor
@Observable
final class PlatformDetailsViewModel {
    let name: String

    init(name: String) {
        self.name = name
    }
}
