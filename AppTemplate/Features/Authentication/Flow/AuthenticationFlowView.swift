import SwiftUI

struct AuthenticationFlowView: View {
    let dependencies: AuthenticationDependencies

    var body: some View {
        NavigationStack {
            AuthenticationView(dependencies: dependencies)
                .navigationDestination(for: AuthenticationRoute.self) { route in
                    switch route {
                    case .help:
                        AuthenticationHelpView()
                    }
                }
        }
        .interactiveDismissDisabled()
    }
}

#Preview("Authentication") {
    PreviewFixtures.authenticationFlow()
}
