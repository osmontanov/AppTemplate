import SwiftUI

struct ProjectBasicsView: View {
    @Environment(\.dismiss) private var dismiss
    private let router: FlowRouter
    private let flowState: CreateProjectFlowState
    @State private var viewModel: ProjectBasicsViewModel

    init(
        router: FlowRouter,
        flowState: CreateProjectFlowState
    ) {
        self.router = router
        self.flowState = flowState
        _viewModel = State(
            initialValue: ProjectBasicsViewModel(router: router)
        )
    }

    var body: some View {
        Form {
            Section("Navigation Example") {
                Text("This screen demonstrates the first step of a modal flow.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Continue") {
                    viewModel.continueToOptions()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("New Project")
        .toolbar {
            Button("Cancel") {
                dismiss()
            }
        }
        .navigationDestination(for: ProjectBasicsRoute.self) { route in
            switch route {
            case .options:
                ProjectOptionsView(
                    router: router,
                    flowState: flowState
                )
            }
        }
    }
}
