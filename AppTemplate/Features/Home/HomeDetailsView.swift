import SwiftUI

struct HomeDetailsView: View {
    @State private var viewModel: HomeDetailsViewModel

    init() {
        _viewModel = State(
            initialValue: HomeDetailsViewModel()
        )
    }

    var body: some View {
        ContentUnavailableView(
            viewModel.title,
            systemImage: viewModel.systemImage,
            description: Text(viewModel.message)
        )
        .navigationTitle("Details")
    }
}
