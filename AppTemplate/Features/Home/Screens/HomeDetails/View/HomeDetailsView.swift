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
                title: viewModel.title,
                systemImage: viewModel.systemImage,
                message: viewModel.message
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
