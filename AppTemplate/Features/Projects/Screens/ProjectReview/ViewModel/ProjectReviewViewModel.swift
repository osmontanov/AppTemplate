import Observation

@MainActor
@Observable
final class ProjectReviewViewModel {
    let draft: CreateProjectDraftState
    private let store: ProjectsStore

    init(
        draft: CreateProjectDraftState,
        store: ProjectsStore
    ) {
        self.draft = draft
        self.store = store
    }

    func save() throws -> ProjectItem {
        if let completedProject = draft.completedProject {
            return completedProject
        }

        let project = try store.addProject(from: draft)
        draft.complete(with: project)
        return project
    }
}
