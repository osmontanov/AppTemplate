import SwiftUI

struct ProjectDetailsView: View {
    private let router: FlowRouter
    @State private var viewModel: ProjectDetailsViewModel

    init(
        projectID: ProjectItem.ID,
        router: FlowRouter
    ) {
        self.router = router
        _viewModel = State(
            initialValue: ProjectDetailsViewModel(
                projectID: projectID,
                router: router
            )
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            Section("Destination") {
                LabeledContent {
                    Text(verbatim: viewModel.projectID)
                } label: {
                    Text("Project Identifier")
                }
            }

            Section("Navigation Examples") {
                Button {
                    viewModel.openTask(id: "work-item-navigation")
                } label: {
                    Label("Navigation Structure", systemImage: "circle")
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.openTask(id: "work-item-presentation")
                } label: {
                    Label("Presentation Structure", systemImage: "circle")
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Project Details")
        .navigationDestination(for: ProjectDetailsRoute.self) { route in
            switch route {
            case let .task(projectID, taskID):
                TaskDetailsView(
                    projectID: projectID,
                    taskID: taskID
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
                ProjectInfoView(projectID: projectID)
            }
        }
    }
}
