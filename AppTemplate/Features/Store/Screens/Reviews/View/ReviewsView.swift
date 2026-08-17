import SwiftUI

struct ReviewsView: View {
    @State private var viewModel: ReviewsViewModel
    @AccessibilityFocusState private var resultIsFocused: Bool

    init(productID: Product.ID, products: any IProductRepository) {
        _viewModel = State(initialValue: ReviewsViewModel(productID: productID, products: products))
    }

    var body: some View {
        List {
            if let product = viewModel.product {
                ForEach(product.reviews) { review in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(AppText.resource("\(review.rating) out of 5"), systemImage: "star.fill")
                        Text(verbatim: review.comment)
                        Text(verbatim: review.reviewerName).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if product.reviews.isEmpty {
                    ContentUnavailableView(AppText.resource("No reviews"), systemImage: "star.bubble")
                        .accessibilityIdentifier(AppAccessibilityIdentifier.result(.empty))
                        .accessibilityFocused($resultIsFocused)
                }
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualFailure))
                    .accessibilityFocused($resultIsFocused)
            } else {
                ProgressView()
                    .accessibilityLabel(AppText.resource("Loading reviews"))
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.loading))
            }
        }
        .navigationTitle(AppText.resource("Reviews"))
        .task(id: viewModel.productID) {
            await viewModel.load()
            resultIsFocused = viewModel.product?.reviews.isEmpty != false
            AccessibilityNotification.Announcement(
                viewModel.product == nil
                    ? AppText.string("Reviews are unavailable")
                    : AppText.string("Reviews loaded")
            ).post()
        }
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.reviews))
    }
}
