import SwiftUI

struct RelatedItemsView: View {
    private let router: FlowRouter
    private let dependencies: BrowseDependencies
    @State private var viewModel: RelatedItemsViewModel

    init(
        sourceItemID: BrowseItem.ID,
        dependencies: BrowseDependencies,
        router: FlowRouter
    ) {
        self.router = router
        self.dependencies = dependencies
        _viewModel = State(
            initialValue: RelatedItemsViewModel(
                sourceItemID: sourceItemID,
                dependencies: dependencies,
                router: router
            )
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                LoadingStateView(title: "Loading Related Items…")
            case .empty:
                EmptyStateView(
                    title: "No Related Items",
                    systemImage: "link",
                    message: "There are no other Browse items."
                )
            case let .content(items):
                List(items) { item in
                    Button {
                        viewModel.openItem(id: item.id)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.title)
                            Text(item.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            case let .failed(failure):
                ErrorStateView(
                    title: "Related Items Unavailable",
                    message: failure.message,
                    retry: {
                        viewModel.retry()
                    }
                )
            }
        }
        .navigationTitle("Related Items")
        .task {
            await viewModel.load()
        }
        .onDisappear {
            viewModel.cancel()
        }
        .navigationDestination(for: RelatedItemsRoute.self) { route in
            switch route {
            case let .item(id):
                RelatedItemDetailView(
                    id: id,
                    dependencies: dependencies
                )
            }
        }
    }
}
