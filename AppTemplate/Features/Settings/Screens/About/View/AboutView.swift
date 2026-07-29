import SwiftUI

struct AboutView: View {
    private let router: FlowRouter
    @State private var viewModel: AboutViewModel

    init(router: FlowRouter) {
        self.router = router
        _viewModel = State(
            initialValue: AboutViewModel(router: router)
        )
    }

    var body: some View {
        List {
            Section("Platforms") {
                ForEach(viewModel.supportedPlatforms, id: \.self) { platform in
                    Button(platform) {
                        viewModel.openPlatform(name: platform)
                    }
                }
            }
            Section("Examples") {
                Text(viewModel.exampleDescription)
            }
        }
        .navigationTitle("About")
        .navigationDestination(for: AboutRoute.self) { route in
            switch route {
            case let .platform(name):
                PlatformDetailsView(name: name)
            }
        }
    }
}
