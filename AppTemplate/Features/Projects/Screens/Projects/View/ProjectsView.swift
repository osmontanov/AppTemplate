import SwiftUI

struct ProjectsView: View {
    private let router: FlowRouter
    @State private var viewModel: ProjectsViewModel

    init(router: FlowRouter) {
        self.router = router
        _viewModel = State(
            initialValue: ProjectsViewModel(router: router)
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            Section("Navigation Examples") {
                Button {
                    viewModel.openProject(id: "project-app-template")
                } label: {
                    VStack(alignment: .leading) {
                        Text("App Template")
                        Text("Open a stable project destination.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.openProject(id: "project-release-readiness")
                } label: {
                    VStack(alignment: .leading) {
                        Text("Release Readiness")
                        Text("Open another stable project destination.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
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
                    router: router
                )
            }
        }
        .sheet(item: $viewModel.sheet) { route in
            switch route {
            case .createProject:
                CreateProjectFlowView(appFlowRouter: router)
            }
        }
    }
}
