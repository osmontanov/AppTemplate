import SwiftUI

struct HomeNavigationView: View {
    @State private var viewModel: HomeViewModel

    init(router: HomeRouter) {
        _viewModel = State(
            initialValue: HomeViewModel(router: router)
        )
    }

    var body: some View {
        @Bindable var router = viewModel.router
        @Bindable var bindableViewModel = viewModel

        NavigationStack(path: $router.path) {
            List {
                Button("Navigation details") {
                    viewModel.openDetails()
                }
                Button("Open navigation guide") {
                    viewModel.openNavigationGuide()
                }
                Button("Reset Home navigation", role: .destructive) {
                    viewModel.requestNavigationReset()
                }
            }
            .navigationTitle("Home")
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .details:
                    HomeDetailsView()
                }
            }
        }
        .sheet(item: $router.sheet) { route in
            switch route {
            case .navigationGuide:
                NavigationStack {
                    NavigationGuideView()
                }
            }
        }
        .alert(
            "Reset Home navigation?",
            isPresented: $bindableViewModel.isResetAlertPresented
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
    }
}
