import SwiftUI

struct RelatedItemDetailView: View {
    @State private var viewModel: RelatedItemDetailViewModel

    init(
        id: BrowseItem.ID,
        dependencies: BrowseDependencies
    ) {
        _viewModel = State(
            initialValue: RelatedItemDetailViewModel(
                id: id,
                dependencies: dependencies
            )
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                LoadingStateView(title: "Loading Related Item…")
            case let .content(item):
                Form {
                    LabeledContent("Identifier", value: item.id)
                    Text(item.summary)
                }
                .navigationTitle(item.title)
            case .empty:
                EmptyStateView(
                    title: "Related Item Unavailable",
                    systemImage: "questionmark.folder",
                    message: "This item no longer exists."
                )
            case let .failed(failure):
                ErrorStateView(
                    title: "Related Item Unavailable",
                    message: failure.message,
                    retry: {
                        viewModel.retry()
                    }
                )
            }
        }
        .task(id: viewModel.id) {
            await viewModel.load()
        }
        .onDisappear {
            viewModel.cancel()
        }
    }
}
