import SwiftUI

struct AppRootView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Bindable var router: AppRouter
    let dependencies: AppDependencies

    var body: some View {
        switch router.flow {
        case .launching:
            ProgressView("Launching…")
        case .authentication:
            AuthenticationPlaceholderView(
                failureMessage: sessionStore.failure?.message,
                canRetryRestoration: sessionStore.failure == .restoration,
                onContinue: {
                    Task { await sessionStore.signIn() }
                },
                onCancel: {
                    _ = router.completeAuthentication(succeeded: false)
                },
                onRetryRestoration: {
                    Task { await sessionStore.retryStart() }
                }
            )
        case .main:
            AppShellView(router: router, dependencies: dependencies)
        }
    }
}

private struct AuthenticationPlaceholderView: View {
    let failureMessage: String?
    let canRetryRestoration: Bool
    let onContinue: () -> Void
    let onCancel: () -> Void
    let onRetryRestoration: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.key")
                .font(.largeTitle)
            Text("Authentication")
                .font(.title)
            Text("Connect the project’s session service here.")
                .foregroundStyle(.secondary)
            if let failureMessage {
                Text(failureMessage)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Cancel", action: onCancel)
                if canRetryRestoration {
                    Button("Retry", action: onRetryRestoration)
                }
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
