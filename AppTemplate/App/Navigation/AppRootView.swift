import SwiftUI

struct AppRootView: View {
    @Bindable var router: AppRouter

    var body: some View {
        switch router.flow {
        case .launching:
            ProgressView("Launching…")
        case .authentication:
            AuthenticationPlaceholderView(
                onContinue: {
                    _ = router.completeAuthentication(succeeded: true)
                },
                onCancel: {
                    _ = router.completeAuthentication(succeeded: false)
                }
            )
        case .main:
            AppShellView(router: router)
        }
    }
}

private struct AuthenticationPlaceholderView: View {
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.key")
                .font(.largeTitle)
            Text("Authentication")
                .font(.title)
            Text("Connect the project’s session service here.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Cancel", action: onCancel)
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
