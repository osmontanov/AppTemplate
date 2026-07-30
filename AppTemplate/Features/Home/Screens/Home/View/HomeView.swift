import SwiftUI

struct HomeView: View {
    private let router: FlowRouter
    @State private var viewModel: HomeViewModel

    init(router: FlowRouter) {
        self.router = router
        _viewModel = State(
            initialValue: HomeViewModel(router: router)
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            Button("Navigation details") {
                viewModel.openDetails()
            }
            Button("Open navigation guide") {
                viewModel.openNavigationGuide()
            }
            Button("Restart onboarding") {
                viewModel.openOnboarding()
            }
            Button("Enable maintenance") {
                viewModel.openMaintenance()
            }
            Button("Quick Start") {
                viewModel.openQuickStart()
            }
            Button("Reset Home navigation", role: .destructive) {
                viewModel.requestNavigationReset()
            }
        }
        .navigationTitle("Home")
        .navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .details:
                HomeDetailsView(router: router)
            case .navigationGuide:
                NavigationGuideView(router: router)
            }
        }
        .alert(
            "Reset Home navigation?",
            isPresented: $viewModel.isResetAlertPresented
        ) {
            Button("Reset", role: .destructive) {
                viewModel.confirmNavigationReset()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelNavigationReset()
            }
        } message: {
            Text("This clears only the Home navigation history.")
        }
        .sheet(item: $viewModel.sheet) { route in
            switch route {
            case .quickStart:
                QuickStartView()
            }
        }
    }
}
