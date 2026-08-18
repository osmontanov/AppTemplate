import SwiftUI

struct SessionRecoveryView: View {
    let session: any ISessionActions
    @State private var viewModel: SessionRecoveryViewModel
    @AccessibilityFocusState private var messageIsFocused: Bool

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
                Text(AppText.resource("Session unavailable")).font(.title)
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($messageIsFocused)
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualFailure))
                Button(AppText.resource("Retry")) {
                    Task {
                        await viewModel.retry()
                        AccessibilityNotification.Announcement(
                            AppText.string("Session recovery status updated")
                        ).post()
                    }
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isRetrying)
                    .frame(minHeight: 44)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(minWidth: 340, minHeight: 300)
        .onChange(of: session.status) { _, status in
            viewModel.sessionDidChange(status)
        }
        .task { messageIsFocused = true }
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.sessionRecovery))
    }

    private var message: String {
        switch viewModel.reason {
        case .secureStorageReadFailed:
            AppText.string("The saved session could not be read safely.")
        case .secureStorageCleanupFailed:
            AppText.string("The saved session could not be removed safely.")
        }
    }
}
