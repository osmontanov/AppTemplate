import Observation

@MainActor
@Observable
final class ProjectInfoViewModel {
    let projectID: ProjectItem.ID

    init(projectID: ProjectItem.ID) {
        self.projectID = projectID
    }
}
