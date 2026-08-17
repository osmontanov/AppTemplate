import SwiftUI

struct ServicesCatalogView: View {
    @Bindable var router: ServicesRouter
    let items: [ServicesCatalogItem]

    init(
        router: ServicesRouter,
        items: [ServicesCatalogItem] = ServicesCatalogViewModel.items
    ) {
        self.router = router
        self.items = items
    }

    var body: some View {
        List(items) { item in
            Button {
                router.open(item.route)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.route.displayTitle)
                    Text(item.guide.why)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                AppAccessibilityIdentifier.serviceDestination(item.route.accessibilityDestination)
            )
        }
        .navigationTitle(AppText.resource("Services"))
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.servicesCatalog))
    }
}
