import SwiftUI

struct BrowseView: View {
    private let router: FlowRouter
    @State private var viewModel: BrowseListViewModel

    init(router: FlowRouter) {
        self.router = router
        _viewModel = State(
            initialValue: BrowseListViewModel(router: router)
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            Button("SwiftUI") {
                viewModel.openItem(id: "swiftui")
            }
            Button("Observation") {
                viewModel.openItem(id: "observation")
            }
            Button("Typed Routing") {
                viewModel.openItem(id: "routing")
            }
        }
        .navigationTitle("Browse")
        .toolbar {
            Button("Options", systemImage: "slider.horizontal.3") {
                viewModel.openOptions()
            }
        }
        .navigationDestination(for: BrowseRoute.self) { route in
            switch route {
            case let .item(id):
                BrowseDetailView(id: id, router: router)
            }
        }
        .sheet(item: $viewModel.sheet, onDismiss: {
            viewModel.dismissSheet()
        }) { route in
            switch route {
            case .options:
                BrowseOptionsView()
            }
        }
    }
}
