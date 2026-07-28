import Observation

@MainActor
@Observable
final class AboutViewModel {
    let supportedPlatforms = [
        "iOS 26",
        "iPadOS 26",
        "macOS 26"
    ]
    let exampleDescription =
        "Home, Browse, and Settings are replaceable feature examples."
}
