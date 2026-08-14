import SwiftUI

struct FavoritesView: View {
    @Bindable var router: StoreRouter
    let userID: Int
    @State private var viewModel: FavoritesViewModel
    @AccessibilityFocusState private var resultIsFocused: Bool

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
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.loading))
            case .empty:
                ContentUnavailableView(StoreServicesText.resource("No favorites"), systemImage: "heart")
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.empty))
                    .accessibilityFocused($resultIsFocused)
            case .failed:
                ContentUnavailableView(StoreServicesText.resource("Favorites are unavailable"), systemImage: "exclamationmark.triangle")
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualFailure))
                    .accessibilityFocused($resultIsFocused)
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
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
        }
        .navigationTitle(StoreServicesText.resource("Favorites"))
        .task(id: userID) {
            await viewModel.load(userID: userID)
            switch viewModel.state {
            case .empty, .failed:
                resultIsFocused = true
            case .idle, .loading, .loaded:
                resultIsFocused = false
            }
            AccessibilityNotification.Announcement(StoreServicesText.string("Favorites updated")).post()
        }
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.favorites))
    }
}
