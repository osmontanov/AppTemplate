import SwiftUI

struct ProjectDetailsView: View {
    private let router: FlowRouter
    @State private var viewModel: ProjectDetailsViewModel

    init(
        projectID: ProjectItem.ID,
        router: FlowRouter,
        store: ProjectsStore
    ) {
        self.router = router
        _viewModel = State(
            initialValue: ProjectDetailsViewModel(
                projectID: projectID,
                store: store,
                router: router
            )
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Group {
            if let project = viewModel.project {
                List(viewModel.tasks) { task in
                    Button {
                        viewModel.openTask(id: task.id)
                    } label: {
                        Label(
                            task.title,
                            systemImage: task.isComplete
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .navigationTitle(project.title)
            } else {
                EmptyStateView(
                    title: "Project Unavailable",
                    systemImage: "questionmark.folder",
                    message: "This project no longer exists."
                )
                .navigationTitle("Project")
            }
        }
        .navigationDestination(for: ProjectDetailsRoute.self) { route in
            switch route {
            case let .task(projectID, taskID):
                TaskDetailsView(
                    projectID: projectID,
                    taskID: taskID,
                    store: viewModel.store
                )
            }
        }
        .toolbar {
            Button("Project Info", systemImage: "info.circle") {
                viewModel.openProjectInfo()
            }
        }
        .sheet(item: $viewModel.sheet) { route in
            switch route {
            case let .projectInfo(projectID):
                ProjectInfoView(
                    projectID: projectID,
                    store: viewModel.store
                )
            }
        }
    }
}
