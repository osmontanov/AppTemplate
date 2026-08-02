import SwiftUI

struct BrowseDetailView: View {
    private let router: FlowRouter
    @State private var viewModel: BrowseDetailViewModel

    init(id: BrowseItem.ID, router: FlowRouter) {
        self.router = router
        _viewModel = State(
            initialValue: BrowseDetailViewModel(id: id, router: router)
        )
    }

    var body: some View {
        Form {
            LabeledContent {
                Text(verbatim: viewModel.id)
            } label: {
                Text("Identifier")
            }
            Text("This static detail keeps the typed Browse route available for navigation examples.")
        }
        .navigationTitle("Browse Detail")
        .toolbar {
            Button("Related Items", systemImage: "link") {
                viewModel.openRelatedItems()
            }
        }
        .navigationDestination(for: BrowseDetailRoute.self) { route in
            switch route {
            case let .relatedItems(itemID):
                RelatedItemsView(sourceItemID: itemID, router: router)
            }
        }
    }
}
