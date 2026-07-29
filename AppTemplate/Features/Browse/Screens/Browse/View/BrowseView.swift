import SwiftUI

struct BrowseView: View {
    private let router: FlowRouter
    @State private var viewModel: BrowseListViewModel
    private let dependencies: BrowseDependencies
    private let preferences: BrowsePreferencesStore

    init(
        router: FlowRouter,
        dependencies: BrowseDependencies,
        preferences: BrowsePreferencesStore
    ) {
        self.router = router
        self.dependencies = dependencies
        self.preferences = preferences
        _viewModel = State(
            initialValue: BrowseListViewModel(
                dependencies: dependencies,
                router: router,
                preferences: preferences
            )
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

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
            case .content:
                List(viewModel.visibleItems) { item in
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
        .toolbar {
            Button("Options", systemImage: "slider.horizontal.3") {
                viewModel.openOptions()
            }
        }
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
        .sheet(item: $viewModel.sheet, onDismiss: {
            viewModel.dismissSheet()
        }) { route in
            switch route {
            case .options:
                BrowseOptionsView(preferences: preferences)
            }
        }
    }
}
