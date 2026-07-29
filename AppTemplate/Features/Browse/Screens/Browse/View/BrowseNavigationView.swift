import SwiftUI

struct BrowseNavigationView: View {
    @Bindable var router: BrowseRouter
    @State private var viewModel: BrowseListViewModel
    private let dependencies: BrowseDependencies

    init(
        router: BrowseRouter,
        dependencies: BrowseDependencies
    ) {
        self.router = router
        self.dependencies = dependencies
        _viewModel = State(
            initialValue: BrowseListViewModel(
                dependencies: dependencies
            )
        )
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingStateView(title: "Loading Browse…")
                case .empty:
                    EmptyStateView(
                        title: "No Browse Items",
                        systemImage: "tray",
                        message: "There are no Browse items yet."
                    )
                case let .content(items):
                    List(items) { item in
                        NavigationLink(value: BrowseRoute.item(id: item.id)) {
                            VStack(alignment: .leading) {
                                Text(item.title)
                                Text(item.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                case let .failed(failure):
                    ErrorStateView(
                        title: "Browse Unavailable",
                        message: failure.message,
                        retry: {
                            viewModel.retry()
                        }
                    )
                }
            }
            .navigationTitle("Browse")
            .task {
                await viewModel.load()
            }
            .onDisappear {
                viewModel.cancel()
            }
            .navigationDestination(for: BrowseRoute.self) { route in
                switch route {
                case let .item(id):
                    BrowseDetailView(
                        id: id,
                        dependencies: dependencies
                    )
                }
            }
        }
    }
}
