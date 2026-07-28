import SwiftUI

struct AboutView: View {
    @State private var viewModel: AboutViewModel

    init() {
        _viewModel = State(
            initialValue: AboutViewModel()
        )
    }

    var body: some View {
        List {
            Section("Platforms") {
                ForEach(viewModel.supportedPlatforms, id: \.self) { platform in
                    Text(platform)
                }
            }
            Section("Examples") {
                Text(viewModel.exampleDescription)
            }
        }
        .navigationTitle("About")
    }
}
