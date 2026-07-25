import SwiftUI

struct BrowseNavigationView: View {
    @Bindable var router: BrowseRouter
    @State private var store: BrowseListStore
    private let repository: any BrowseRepository

    init(router: BrowseRouter, repository: any BrowseRepository) {
        self.router = router
        self.repository = repository
        _store = State(initialValue: BrowseListStore(repository: repository))
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            Group {
                switch store.state {
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
                            Task { await store.load() }
                        }
                    }
                }
            }
            .navigationTitle("Browse")
            .task {
                await store.load()
            }
            .navigationDestination(for: BrowseRoute.self) { route in
                switch route {
                case let .item(id):
                    BrowseDetailView(id: id, repository: repository)
                }
            }
        }
    }
}

private struct BrowseDetailView: View {
    @State private var store: BrowseDetailStore

    init(id: BrowseItem.ID, repository: any BrowseRepository) {
        _store = State(
            initialValue: BrowseDetailStore(id: id, repository: repository)
        )
    }

    var body: some View {
        Group {
            switch store.state {
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
                        Task { await store.load() }
                    }
                }
            }
        }
        .task(id: store.id) {
            await store.load()
        }
    }
}
