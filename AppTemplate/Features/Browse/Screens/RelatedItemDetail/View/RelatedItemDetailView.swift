import SwiftUI

struct RelatedItemDetailView: View {
    @State private var viewModel: RelatedItemDetailViewModel

    init(id: BrowseItem.ID) {
        _viewModel = State(initialValue: RelatedItemDetailViewModel(id: id))
    }

    var body: some View {
        Form {
            LabeledContent {
                Text(verbatim: viewModel.id)
            } label: {
                Text("Identifier")
            }
            Text("This static related-item detail keeps the typed destination available for navigation examples.")
        }
        .navigationTitle("Related Item Detail")
    }
}
