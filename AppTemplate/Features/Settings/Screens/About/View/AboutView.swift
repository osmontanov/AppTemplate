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
                Button("iOS 26") {
                    viewModel.openPlatform(name: "iOS 26")
                }
                Button("iPadOS 26") {
                    viewModel.openPlatform(name: "iPadOS 26")
                }
                Button("macOS 26") {
                    viewModel.openPlatform(name: "macOS 26")
                }
            }
            Section("Examples") {
                Text(
                    "Home, Browse, Projects, and Settings are replaceable feature examples."
                )
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
