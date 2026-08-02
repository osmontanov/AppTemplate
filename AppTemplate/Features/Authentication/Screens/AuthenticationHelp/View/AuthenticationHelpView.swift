import SwiftUI

struct AuthenticationHelpView: View {
    @State private var viewModel = AuthenticationHelpViewModel()

    var body: some View {
        AdaptiveContentContainer {
            VStack(spacing: 16) {
                Image(systemName: "questionmark.circle")
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                Text("Authentication Help")
                    .font(.title)
                Text("Continue replaces the Authentication root with Main.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Help")
    }
}
