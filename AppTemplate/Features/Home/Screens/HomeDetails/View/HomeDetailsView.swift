import SwiftUI

struct HomeDetailsView: View {
    @State private var viewModel: HomeDetailsViewModel

    init() {
        _viewModel = State(
            initialValue: HomeDetailsViewModel()
        )
    }

    var body: some View {
        EmptyStateView(
            title: viewModel.title,
            systemImage: viewModel.systemImage,
            message: viewModel.message
        )
        .navigationTitle("Details")
    }
}
