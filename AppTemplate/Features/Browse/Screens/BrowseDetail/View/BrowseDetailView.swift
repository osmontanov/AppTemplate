import SwiftUI

struct BrowseDetailView: View {
    @State private var viewModel: BrowseDetailViewModel

    init(
        id: BrowseItem.ID,
        dependencies: BrowseDependencies
    ) {
        _viewModel = State(
            initialValue: BrowseDetailViewModel(
                id: id,
                dependencies: dependencies
            )
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                LoadingStateView(title: "Loading Item…")
            case let .content(item):
                Form {
                    LabeledContent("Identifier", value: item.id)
                    Text(item.summary)
                }
                .navigationTitle(item.title)
            case .empty:
                EmptyStateView(
                    title: "Item Unavailable",
                    systemImage: "questionmark.folder",
                    message: "This item no longer exists."
                )
            case let .failed(failure):
                ErrorStateView(
                    title: "Item Unavailable",
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
