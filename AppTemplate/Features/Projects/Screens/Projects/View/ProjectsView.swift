import SwiftUI

struct ProjectsView: View {
    private let router: FlowRouter
    @State private var viewModel: ProjectsViewModel

    init(
        router: FlowRouter,
        store: ProjectsStore
    ) {
        self.router = router
        _viewModel = State(
            initialValue: ProjectsViewModel(
                store: store,
                router: router
            )
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Group {
            if viewModel.projects.isEmpty {
                EmptyStateView(
                    title: "No Projects",
                    systemImage: "folder",
                    message: "There are no projects yet."
                )
            } else {
                List(viewModel.projects) { project in
                    Button {
                        viewModel.openProject(id: project.id)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(project.title)
                            Text(project.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            Button("New Project", systemImage: "plus") {
                viewModel.openCreateProject()
            }
        }
        .navigationDestination(for: ProjectsRoute.self) { route in
            switch route {
            case let .project(id):
                ProjectDetailsView(
                    projectID: id,
                    router: router,
                    store: viewModel.store
                )
            }
        }
        .sheet(item: $viewModel.sheet) { route in
            switch route {
            case .createProject:
                CreateProjectFlowView(
                    store: viewModel.store,
                    appFlowRouter: router
                )
            }
        }
    }
}
