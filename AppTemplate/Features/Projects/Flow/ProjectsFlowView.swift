import SwiftUI

struct ProjectsFlowView: View {
    @Bindable var router: FlowRouter

    init(router: FlowRouter) {
        self.router = router
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            ProjectsView(router: router)
        }
    }
}

#Preview("Projects") {
    PreviewFixtures.projectsFlow()
}
