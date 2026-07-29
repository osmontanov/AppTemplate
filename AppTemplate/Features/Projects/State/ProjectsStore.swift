import Foundation
import Observation

nonisolated
enum ProjectsStoreError: Error, Equatable, Sendable {
    case emptyTitle
}

@MainActor
@Observable
final class ProjectsStore {
    private(set) var projects: [ProjectItem]

    init(projects: [ProjectItem]) {
        self.projects = projects
    }

    convenience init() {
        self.init(projects: Self.exampleProjects)
    }

    func project(id: ProjectItem.ID) -> ProjectItem? {
        projects.first { $0.id == id }
    }

    func task(
        projectID: ProjectItem.ID,
        taskID: ProjectTaskItem.ID
    ) -> ProjectTaskItem? {
        project(id: projectID)?.tasks.first { $0.id == taskID }
    }

    func addProject(from draft: CreateProjectDraftState) throws -> ProjectItem {
        guard !draft.trimmedTitle.isEmpty else {
            throw ProjectsStoreError.emptyTitle
        }

        let project = ProjectItem(
            id: UUID().uuidString,
            title: draft.trimmedTitle,
            summary: draft.summary,
            colorName: draft.colorName,
            tasks: []
        )
        projects.append(project)
        return project
    }

    private static let exampleProjects = [
        ProjectItem(
            id: "project-1",
            title: "App Template",
            summary: "Expand navigation and sheets.",
            colorName: "blue",
            tasks: [
                ProjectTaskItem(
                    id: "task-1",
                    title: "Build Projects",
                    isComplete: false
                )
            ]
        ),
        ProjectItem(
            id: "project-2",
            title: "Release Readiness",
            summary: "Prepare the next release.",
            colorName: "indigo",
            tasks: [
                ProjectTaskItem(
                    id: "task-2",
                    title: "Review the release notes",
                    isComplete: true
                )
            ]
        )
    ]
}
