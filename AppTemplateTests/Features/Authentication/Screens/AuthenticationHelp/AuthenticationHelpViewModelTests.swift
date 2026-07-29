import Testing
@testable import AppTemplate

@MainActor
struct AuthenticationHelpViewModelTests {
    @Test
    func helpScreenCanBeConstructed() {
        _ = AuthenticationHelpView()
    }
}
