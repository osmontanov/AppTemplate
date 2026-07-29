import SwiftUI

struct ProjectsFlowView: View {
    @Bindable var router: FlowRouter
    @State private var store: ProjectsStore

    init(
        router: FlowRouter,
        dependencies _: ProjectsDependencies
    ) {
        self.router = router
        _store = State(initialValue: ProjectsStore())
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            ProjectsView(
                router: router,
                store: store
            )
        }
    }
}
