import SwiftUI

struct CreateProjectFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var router: FlowRouter
    @State private var draft: CreateProjectDraftState

    let store: ProjectsStore

    init(
        store: ProjectsStore,
        appFlowRouter: any IAppFlowRouter
    ) {
        self.init(
            store: store,
            draft: CreateProjectDraftState(),
            appFlowRouter: appFlowRouter
        )
    }

    init(
        store: ProjectsStore,
        draft: CreateProjectDraftState,
        appFlowRouter: any IAppFlowRouter
    ) {
        self.store = store
        _router = State(
            initialValue: FlowRouter(appFlowRouter: appFlowRouter)
        )
        _draft = State(initialValue: draft)
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            ProjectBasicsView(
                draft: draft,
                router: router,
                store: store
            )
        }
        .onChange(of: draft.isComplete) { _, isComplete in
            guard isComplete else {
                return
            }
            dismiss()
        }
    }
}
