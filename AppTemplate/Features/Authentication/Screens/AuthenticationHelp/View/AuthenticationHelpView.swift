import SwiftUI

struct AuthenticationHelpView: View {
    @State private var viewModel = AuthenticationHelpViewModel()

    var body: some View {
        AdaptiveContentContainer {
            VStack(spacing: 16) {
                Image(systemName: "questionmark.circle")
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                Text(AppText.resource("Authentication Help"))
                    .font(.title)
                    .accessibilityAddTraits(.isHeader)
                Text(AppText.resource("Sign in to continue the protected Store action. Cancel returns to the Store."))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(AppText.resource("Help"))
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.authentication))
    }
}
