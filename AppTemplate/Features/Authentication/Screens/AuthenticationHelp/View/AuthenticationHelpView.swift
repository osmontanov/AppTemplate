import SwiftUI

struct AuthenticationHelpView: View {
    @State private var viewModel = AuthenticationHelpViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.largeTitle)
            Text("Authentication Help")
                .font(.title)
            Text("Sign in to continue to the app.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Help")
    }
}
