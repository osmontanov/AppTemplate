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
                ProgressView("Loading Item…")
            case let .content(item):
                Form {
                    LabeledContent("Identifier", value: item.id)
                    Text(item.summary)
                }
                .navigationTitle(item.title)
            case .notFound:
                ContentUnavailableView(
                    "Item Unavailable",
                    systemImage: "questionmark.folder",
                    description: Text("This item no longer exists.")
                )
            case let .failed(failure):
                ContentUnavailableView {
                    Label(
                        "Item Unavailable",
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
        .task(id: viewModel.id) {
            await viewModel.load()
        }
        .onDisappear {
            viewModel.cancel()
        }
    }
}
