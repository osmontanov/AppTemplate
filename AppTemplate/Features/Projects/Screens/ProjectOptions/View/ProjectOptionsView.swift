import SwiftUI

struct ProjectOptionsView: View {
    private static let colorNames = ["blue", "indigo", "green", "orange"]

    private let draft: CreateProjectDraftState
    private let router: FlowRouter
    private let store: ProjectsStore
    @State private var viewModel: ProjectOptionsViewModel

    init(
        draft: CreateProjectDraftState,
        router: FlowRouter,
        store: ProjectsStore
    ) {
        self.draft = draft
        self.router = router
        self.store = store
        _viewModel = State(
            initialValue: ProjectOptionsViewModel(
                draft: draft,
                router: router
            )
        )
    }

    var body: some View {
        @Bindable var draft = draft

        Form {
            Section("Color") {
                Picker("Color", selection: $draft.colorName) {
                    ForEach(Self.colorNames, id: \.self) { colorName in
                        Text(colorName.capitalized)
                            .tag(colorName)
                    }
                }
            }

            Section {
                Button("Continue") {
                    viewModel.continueToReview()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Options")
        .navigationDestination(for: ProjectOptionsRoute.self) { route in
            switch route {
            case .review:
                ProjectReviewView(
                    draft: draft,
                    store: store
                )
            }
        }
    }
}
