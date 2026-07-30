import SwiftUI

struct HomeDetailsView: View {
    private let router: FlowRouter
    @State private var viewModel: HomeDetailsViewModel

    init(router: FlowRouter) {
        self.router = router
        _viewModel = State(
            initialValue: HomeDetailsViewModel(router: router)
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                title: "Reusable Destination",
                systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                message: "This screen uses the router of the flow that opened it."
            )

            Button("Open navigation guide") {
                viewModel.openNavigationGuide()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Details")
        .navigationDestination(for: HomeDetailsRoute.self) { route in
            switch route {
            case .navigationGuide:
                NavigationGuideView(router: router)
            }
        }
    }
}
