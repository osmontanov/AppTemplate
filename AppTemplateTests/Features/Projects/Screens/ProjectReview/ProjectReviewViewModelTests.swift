import Testing
@testable import AppTemplate

@MainActor
struct ProjectReviewViewModelTests {
    @Test
    func reviewSavesExactlyOneProject() throws {
        let store = ProjectsStore(projects: [])
        let draft = CreateProjectDraftState()
        draft.title = "Template"
        let viewModel = ProjectReviewViewModel(draft: draft, store: store)

        let created = try viewModel.save()

        #expect(store.projects == [created])
    }

    @Test
    func editingDraftWithoutSavingLeavesStoreUnchanged() {
        let store = ProjectsStore(projects: [])
        let draft = CreateProjectDraftState()
        draft.title = "Discarded"
        draft.summary = "Close the sheet before Review saves."

        #expect(store.projects.isEmpty)
    }
}
