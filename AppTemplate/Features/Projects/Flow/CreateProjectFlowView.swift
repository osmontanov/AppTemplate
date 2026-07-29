import SwiftUI

struct CreateProjectFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var router = FlowRouter()
    @State private var draft = CreateProjectDraftState()

    let store: ProjectsStore

    init(store: ProjectsStore) {
        self.init(
            store: store,
            draft: CreateProjectDraftState()
        )
    }

    init(store: ProjectsStore, draft: CreateProjectDraftState) {
        self.store = store
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
