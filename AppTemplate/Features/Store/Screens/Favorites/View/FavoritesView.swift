import SwiftUI

struct FavoritesView: View {
    @Bindable var router: StoreRouter
    let userID: Int
    @State private var viewModel: FavoritesViewModel

    init(
        router: StoreRouter,
        repository: any IFavoritesRepository,
        userID: Int
    ) {
        self.router = router
        self.userID = userID
        _viewModel = State(initialValue: FavoritesViewModel(repository: repository))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView(StoreServicesText.resource("Loading favorites"))
            case .empty:
                ContentUnavailableView(StoreServicesText.resource("No favorites"), systemImage: "heart")
            case .failed:
                ContentUnavailableView(StoreServicesText.resource("Favorites are unavailable"), systemImage: "exclamationmark.triangle")
            case let .loaded(model):
                List(model.items) { favorite in
                    HStack {
                        Button(favorite.product.title) {
                            router.push(.product(favorite.product.id))
                        }
                        Spacer()
                        Button(StoreServicesText.resource("Remove"), systemImage: "heart.slash") {
                            Task {
                                await viewModel.remove(
                                    productID: favorite.product.id,
                                    userID: userID
                                )
                            }
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel(StoreServicesText.resource("Remove \(favorite.product.title)"))
                    }
                }
            }
        }
        .navigationTitle(StoreServicesText.resource("Favorites"))
        .task(id: userID) { await viewModel.load(userID: userID) }
        .accessibilityIdentifier("screen.store.favorites")
    }
}
