import Testing
@testable import AppTemplate

@MainActor
struct AuthenticationHelpViewModelTests {
    @Test
    func helpViewModelAndScreenCanBeConstructedWithoutDependencies() {
        _ = AuthenticationHelpViewModel()
        _ = AuthenticationHelpView()
    }
}
