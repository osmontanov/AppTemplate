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
                    ProgressView("Loading Browse…")
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
                    ContentUnavailableView {
                        Label(
                            "Browse Unavailable",
                            systemImage: "exclamationmark.triangle"
                        )
                    } description: {
                        Text(failure.message)
                    } actions: {
                        Button("Retry") {
                            viewModel.retry()
                        }
                    }
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
