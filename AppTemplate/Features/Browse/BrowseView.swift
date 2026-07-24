import SwiftUI

struct BrowseNavigationView: View {
    @Bindable var router: BrowseRouter
    private let catalog = SampleBrowseCatalog()

    var body: some View {
        NavigationStack(path: $router.path) {
            List(SampleBrowseCatalog.items) { item in
                NavigationLink(value: BrowseRoute.item(id: item.id)) {
                    VStack(alignment: .leading) {
                        Text(item.title)
                        Text(item.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Browse")
            .navigationDestination(for: BrowseRoute.self) { route in
                switch route {
                case let .item(id):
                    if let item = catalog.item(id: id) {
                        BrowseDetailView(item: item)
                    } else {
                        ContentUnavailableView(
                            "Item Unavailable",
                            systemImage: "questionmark.folder",
                            description: Text("This item no longer exists.")
                        )
                    }
                }
            }
        }
    }
}

private struct BrowseDetailView: View {
    let item: BrowseItem

    var body: some View {
        Form {
            LabeledContent("Identifier", value: item.id)
            Text(item.summary)
        }
        .navigationTitle(item.title)
    }
}
