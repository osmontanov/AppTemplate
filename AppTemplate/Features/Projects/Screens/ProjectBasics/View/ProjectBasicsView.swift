import SwiftUI

struct ProjectBasicsView: View {
    @Environment(\.dismiss) private var dismiss
    private let draft: CreateProjectDraftState
    private let router: FlowRouter
    private let store: ProjectsStore
    @State private var viewModel: ProjectBasicsViewModel

    init(
        draft: CreateProjectDraftState,
        router: FlowRouter,
        store: ProjectsStore
    ) {
        self.draft = draft
        self.router = router
        self.store = store
        _viewModel = State(
            initialValue: ProjectBasicsViewModel(
                draft: draft,
                router: router
            )
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var draft = draft

        Form {
            Section("Project") {
                TextField("Name", text: $draft.title)
                TextField("Summary", text: $draft.summary, axis: .vertical)
            }

            if let validationMessage = viewModel.validationMessage {
                Text(validationMessage)
                    .foregroundStyle(.red)
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
                    draft: draft,
                    router: router,
                    store: store
                )
            }
        }
    }
}
