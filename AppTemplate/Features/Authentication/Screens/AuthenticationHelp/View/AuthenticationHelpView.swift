import SwiftUI

struct AuthenticationHelpView: View {
    @State private var viewModel = AuthenticationHelpViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.largeTitle)
            Text(viewModel.title)
                .font(.title)
            Text(viewModel.message)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Help")
    }
}
