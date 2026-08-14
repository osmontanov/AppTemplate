import SwiftUI

struct ServicesCatalogView: View {
    let items: [ServicesCatalogItem]

    init(items: [ServicesCatalogItem] = ServicesCatalogViewModel.items) {
        self.items = items
    }

    var body: some View {
        List(items) { item in
            NavigationLink(value: item.route) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.route.displayTitle)
                    Text(item.guide.why)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .accessibilityIdentifier("route.services.\(item.route.accessibilityWireValue)")
        }
        .navigationTitle(StoreServicesText.resource(.servicesTitle))
        .accessibilityIdentifier("screen.services.root")
    }
}
