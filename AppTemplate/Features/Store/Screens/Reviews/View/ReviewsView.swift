import SwiftUI

struct ReviewsView: View {
    @State private var viewModel: ReviewsViewModel

    init(productID: Product.ID, products: any IProductRepository) {
        _viewModel = State(initialValue: ReviewsViewModel(productID: productID, products: products))
    }

    var body: some View {
        List {
            if let product = viewModel.product {
                ForEach(product.reviews) { review in
                    VStack(alignment: .leading, spacing: 6) {
                        Label("\(review.rating) out of 5", systemImage: "star.fill")
                        Text(verbatim: review.comment)
                        Text(verbatim: review.reviewerName).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if product.reviews.isEmpty {
                    ContentUnavailableView("No reviews", systemImage: "star.bubble")
                }
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Reviews")
        .task(id: viewModel.productID) { await viewModel.load() }
        .accessibilityIdentifier("screen.store.reviews")
    }
}
