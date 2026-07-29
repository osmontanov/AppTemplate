import Testing
@testable import AppTemplate

@MainActor
struct ProjectsStoreTests {
    @Test
    func storeLooksUpProjectsAndTasksByStableID() throws {
        let task = ProjectTaskItem(id: "task-1", title: "Ship", isComplete: false)
        let project = ProjectItem(
            id: "project-1",
            title: "Template",
            summary: "Navigation work",
            colorName: "blue",
            tasks: [task]
        )
        let store = ProjectsStore(projects: [project])

        #expect(store.project(id: "project-1") == project)
        #expect(store.task(projectID: "project-1", taskID: "task-1") == task)
        #expect(store.project(id: "missing") == nil)
    }

    @Test
    func addingDraftCreatesExactlyOneProject() throws {
        let store = ProjectsStore(projects: [])
        let draft = CreateProjectDraftState()
        draft.title = "  New Project  "
        draft.summary = "Example"
        draft.colorName = "indigo"

        let created = try store.addProject(from: draft)

        #expect(store.projects == [created])
        #expect(created.title == "New Project")
        #expect(created.tasks.isEmpty)
    }

    @Test
    func addingWhitespaceOnlyDraftThrowsAndPreservesProjects() throws {
        let existing = ProjectItem(
            id: "existing",
            title: "Existing",
            summary: "Already here",
            colorName: "blue",
            tasks: []
        )
        let store = ProjectsStore(projects: [existing])
        let draft = CreateProjectDraftState()
        draft.title = " \n \t "

        #expect(throws: ProjectsStoreError.emptyTitle) {
            try store.addProject(from: draft)
        }
        #expect(store.projects == [existing])
    }

    @Test
    func defaultStoreProvidesDeterministicExampleProjects() {
        let first = ProjectsStore()
        let second = ProjectsStore()

        #expect(first.projects == second.projects)
        #expect(!first.projects.isEmpty)
    }
}
