import SwiftUI

struct RelatedItemsView: View {
    private let router: FlowRouter
    @State private var viewModel: RelatedItemsViewModel

    init(sourceItemID: BrowseItem.ID, router: FlowRouter) {
        self.router = router
        _viewModel = State(
            initialValue: RelatedItemsViewModel(sourceItemID: sourceItemID, router: router)
        )
    }

    var body: some View {
        List {
            Section("Examples") {
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
        }
        .navigationTitle("Related Items")
        .navigationDestination(for: RelatedItemsRoute.self) { route in
            switch route {
            case let .item(id):
                RelatedItemDetailView(id: id)
            }
        }
    }
}
