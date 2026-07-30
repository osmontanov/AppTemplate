import SwiftUI

struct CreateProjectFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var router: FlowRouter
    @State private var flowState: CreateProjectFlowState

    var localRouter: FlowRouter {
        router
    }

    init(appFlowRouter: any IAppFlowRouter) {
        self.init(
            flowState: CreateProjectFlowState(),
            appFlowRouter: appFlowRouter
        )
    }

    init(
        flowState: CreateProjectFlowState,
        appFlowRouter: any IAppFlowRouter
    ) {
        _router = State(
            initialValue: FlowRouter(appFlowRouter: appFlowRouter)
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
