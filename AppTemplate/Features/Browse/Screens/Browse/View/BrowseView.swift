import SwiftUI

struct BrowseView: View {
    private let router: FlowRouter
    @State private var viewModel: BrowseListViewModel
    private let dependencies: BrowseDependencies

    init(
        router: FlowRouter,
        dependencies: BrowseDependencies
    ) {
        self.router = router
        self.dependencies = dependencies
        _viewModel = State(
            initialValue: BrowseListViewModel(
                dependencies: dependencies,
                router: router
            )
        )
    }

    var body: some View {
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
