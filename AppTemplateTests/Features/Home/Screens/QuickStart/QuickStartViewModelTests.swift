import Testing
import SwiftUI
@testable import AppTemplate

@MainActor
struct QuickStartViewModelTests {
    @Test
    func quickStartViewModelCanBeConstructed() {
        _ = QuickStartViewModel()
    }

    @Test
    func quickStartScreenCanBeConstructed() {
        _ = QuickStartView()
    }
}
