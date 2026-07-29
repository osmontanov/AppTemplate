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
    func successfulSaveCompletesTheCreationFlow() throws {
        let store = ProjectsStore(projects: [])
        let draft = CreateProjectDraftState()
        draft.title = "Template"
        let viewModel = ProjectReviewViewModel(draft: draft, store: store)

        _ = try viewModel.save()

        #expect(draft.isComplete)
    }

    @Test
    func repeatedSaveReturnsTheSameProjectWithoutDuplicateInsertion() throws {
        let store = ProjectsStore(projects: [])
        let draft = CreateProjectDraftState()
        draft.title = "Template"
        let viewModel = ProjectReviewViewModel(draft: draft, store: store)

        let first = try viewModel.save()
        let second = try viewModel.save()

        #expect(second == first)
        #expect(second.id == first.id)
        #expect(store.projects == [first])
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
