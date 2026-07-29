import SwiftUI

struct CreateProjectFlowView: View {
    @State private var router = FlowRouter()
    @State private var draft = CreateProjectDraftState()

    let store: ProjectsStore

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            ProjectBasicsView(
                draft: draft,
                router: router,
                store: store
            )
        }
    }
}
