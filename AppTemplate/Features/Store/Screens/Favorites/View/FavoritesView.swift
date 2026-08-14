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
                ProgressView("Loading favorites")
            case .empty:
                ContentUnavailableView("No favorites", systemImage: "heart")
            case .failed:
                ContentUnavailableView("Favorites are unavailable", systemImage: "exclamationmark.triangle")
            case let .loaded(model):
                List(model.items) { favorite in
                    HStack {
                        Button(favorite.product.title) {
                            router.push(.product(favorite.product.id))
                        }
                        Spacer()
                        Button("Remove", systemImage: "heart.slash") {
                            Task {
                                await viewModel.remove(
                                    productID: favorite.product.id,
                                    userID: userID
                                )
                            }
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Remove \(favorite.product.title)")
                    }
                }
            }
        }
        .navigationTitle("Favorites")
        .task(id: userID) { await viewModel.load(userID: userID) }
        .accessibilityIdentifier("screen.store.favorites")
    }
}
