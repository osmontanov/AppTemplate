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
                Button(AppPlatform.iOS.localizedTitle) {
                    viewModel.openPlatform(.iOS)
                }
                Button(AppPlatform.iPadOS.localizedTitle) {
                    viewModel.openPlatform(.iPadOS)
                }
                Button(AppPlatform.macOS.localizedTitle) {
                    viewModel.openPlatform(.macOS)
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
            case let .platform(platform):
                PlatformDetailsView(platform: platform)
            }
        }
    }
}
