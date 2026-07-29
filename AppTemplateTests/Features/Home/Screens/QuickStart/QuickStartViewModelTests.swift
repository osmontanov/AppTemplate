import Testing
@testable import AppTemplate

@MainActor
struct QuickStartViewModelTests {
    @Test
    func quickStartScreenCanBeConstructed() {
        _ = QuickStartView()
    }
}
