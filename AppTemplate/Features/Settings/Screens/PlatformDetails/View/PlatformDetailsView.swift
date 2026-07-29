import SwiftUI

struct PlatformDetailsView: View {
    @State private var viewModel: PlatformDetailsViewModel

    init(name: String) {
        _viewModel = State(
            initialValue: PlatformDetailsViewModel(name: name)
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "laptopcomputer")
                .font(.largeTitle)
            Text(viewModel.name)
                .font(.title)
            Text("Platform Details")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Platform Details")
    }
}
