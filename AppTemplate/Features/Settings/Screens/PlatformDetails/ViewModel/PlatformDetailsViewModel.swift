import Observation

@MainActor
@Observable
final class PlatformDetailsViewModel {
    let platform: AppPlatform

    init(platform: AppPlatform) {
        self.platform = platform
    }
}
