import Testing
@testable import AppTemplate

@MainActor
struct QuickStartViewModelTests {
    @Test
    func quickStartExplainsTheMainTemplatePaths() {
        let viewModel = QuickStartViewModel()

        #expect(
            viewModel.message
                == """
                Explore five independent flows—Authentication, Home, Browse, \
                Projects, and Settings—plus screen-owned simple sheets and the \
                independent create-project modal flow.
                """
        )
    }

    @Test
    func quickStartScreenCanBeConstructed() {
        _ = QuickStartView()
    }
}
