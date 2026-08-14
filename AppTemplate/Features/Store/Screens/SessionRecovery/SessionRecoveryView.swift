import SwiftUI

struct SessionRecoveryView: View {
    let session: any ISessionActions
    @State private var viewModel: SessionRecoveryViewModel

    init(
        reason: SessionUnavailableReason,
        session: any ISessionActions,
        onResolved: @escaping () -> Void
    ) {
        self.session = session
        _viewModel = State(initialValue: SessionRecoveryViewModel(
            reason: reason,
            session: session,
            onResolved: onResolved
        ))
    }

    var body: some View {
        AdaptiveContentContainer {
            VStack(spacing: 16) {
                Image(systemName: "lock.trianglebadge.exclamationmark")
                    .font(.largeTitle)
                Text("Session unavailable").font(.title)
                Text(message).foregroundStyle(.secondary)
                Button("Retry") { Task { await viewModel.retry() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isRetrying)
            }
        }
        .frame(minWidth: 340, minHeight: 300)
        .onChange(of: session.status) { _, status in
            viewModel.sessionDidChange(status)
        }
        .accessibilityIdentifier("screen.session-recovery")
    }

    private var message: String {
        switch viewModel.reason {
        case .secureStorageReadFailed:
            "The saved session could not be read safely."
        case .secureStorageCleanupFailed:
            "The saved session could not be removed safely."
        }
    }
}
