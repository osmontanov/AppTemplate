import SwiftUI

struct AuthenticationHelpView: View {
    @State private var viewModel = AuthenticationHelpViewModel()

    var body: some View {
        AdaptiveContentContainer {
            VStack(spacing: 16) {
                Image(systemName: "questionmark.circle")
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                Text(StoreServicesText.resource("Authentication Help"))
                    .font(.title)
                Text(StoreServicesText.resource("Sign in to continue the protected Store action. Cancel returns to the Store."))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(StoreServicesText.resource("Help"))
    }
}
