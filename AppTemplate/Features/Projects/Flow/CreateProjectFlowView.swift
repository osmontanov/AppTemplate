import SwiftUI

struct CreateProjectFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var router: FlowRouter
    @State private var flowState: CreateProjectFlowState

    var localRouter: FlowRouter {
        router
    }

    init(appFlowCoordinator: any IAppFlowCoordinator) {
        self.init(
            flowState: CreateProjectFlowState(),
            appFlowCoordinator: appFlowCoordinator
        )
    }

    init(
        flowState: CreateProjectFlowState,
        appFlowCoordinator: any IAppFlowCoordinator
    ) {
        _router = State(
            initialValue: FlowRouter(
                appFlowCoordinator: appFlowCoordinator
            )
        )
        _flowState = State(initialValue: flowState)
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            ProjectBasicsView(
                router: router,
                flowState: flowState
            )
        }
        .onChange(of: flowState.isFinished) { _, isFinished in
            guard isFinished else {
                return
            }
            dismiss()
        }
    }
}

#Preview("Create Project") {
    PreviewFixtures.createProjectFlow()
}
