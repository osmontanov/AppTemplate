import SwiftUI

struct ServicesAppStateView: View {
    private let guide: ServiceLabGuide
    @State private var model: ServicesAppStateViewModel
    @State private var pendingAppAction: AppWideAction?

    init(
        guide: ServiceLabGuide,
        dependencies: ServicesDependencies,
        sceneNavigation: any ISceneNavigationActions
    ) {
        self.guide = guide
        _model = State(initialValue: ServicesAppStateViewModel(
            appState: dependencies.appState,
            appFlowCoordinator: dependencies.appFlowCoordinator,
            sessionActions: dependencies.sessionActions,
            status: dependencies.appStateStatus,
            sceneNavigation: sceneNavigation
        ))
    }

    var body: some View {
        ServiceLabGuideView(
            guide: guide,
            result: model.lastResult,
            resetDemoData: model.resetNavigationInCurrentScene
        ) {
            applicationSummary
            sessionSummary
            windowActions
            appWideActions
        } advanced: {
            sceneSummary
        }
        .navigationTitle("App State")
        .accessibilityIdentifier("screen.services.app-state")
        .confirmationDialog(
            "Confirm Application-wide Action",
            isPresented: appActionConfirmation,
            titleVisibility: .visible,
            presenting: pendingAppAction
        ) { action in
            Button(action.confirmationLabel, role: action.role) {
                perform(action)
            }
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(action.confirmationMessage)
        }
    }

    private var applicationSummary: some View {
        Group {
            Text("Application")
                .font(.headline)
            LabeledContent("Schema", value: "\(model.application.schemaVersion)")
            LabeledContent("Persistence", value: persistenceLabel)
            LabeledContent("Visible Root", value: rootLabel)
            LabeledContent(
                "Onboarding Complete",
                value: model.application.hasCompletedOnboarding ? "Yes" : "No"
            )
            LabeledContent(
                "Maintenance",
                value: model.application.isMaintenanceEnabled ? "Enabled" : "Disabled"
            )
        }
    }

    private var sessionSummary: some View {
        Group {
            Text("Session")
                .font(.headline)
            LabeledContent("State", value: sessionLabel)
            LabeledContent("Revision", value: "\(model.session.session.revision)")
            if let expiry = model.session.expiry {
                LabeledContent(
                    "Access Expiry",
                    value: dateLabel(expiry.accessExpiresAt)
                )
                LabeledContent(
                    "Refresh Expiry",
                    value: dateLabel(expiry.refreshExpiresAt)
                )
            }
        }
    }

    private var windowActions: some View {
        Group {
            Text("Current Window")
                .font(.headline)
            Button("Open App Info Sample Link") {
                model.handleSampleIntent(.openService(.appInfo))
            }
            Button("Open Store Sample Link") {
                model.handleSampleIntent(.openStoreRoot)
            }
            Text("Sample links and Reset Demo Data affect only this window.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appWideActions: some View {
        Group {
            Text("Application-wide")
                .font(.headline)
            Button("Replay Onboarding") {
                pendingAppAction = .replayOnboarding
            }
            Button(model.application.isMaintenanceEnabled
                ? "Disable Maintenance" : "Enable Maintenance") {
                pendingAppAction = .setMaintenance(
                    !model.application.isMaintenanceEnabled
                )
            }
            Button("Sign Out", role: .destructive) {
                pendingAppAction = .signOut
            }
            Text("These commands can change every window and require confirmation.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sceneSummary: some View {
        Group {
            LabeledContent(
                "Selected Section",
                value: model.scene.selectedSection == .store ? "Store" : "Services"
            )
            LabeledContent("Store Path", value: pathCount(model.scene.storePath.count))
            LabeledContent(
                "Services Path",
                value: model.scene.servicesPath.isEmpty
                    ? "Root"
                    : model.scene.servicesPath.map(\.displayTitle).joined(separator: " → ")
            )
            LabeledContent("Restoration", value: restorationLabel)
            LabeledContent(
                "Checkpoint",
                value: model.scene.checkpoint?.uuidString ?? "None"
            )
            LabeledContent(
                "Deferred Link",
                value: model.scene.hasDeferredLink ? "Waiting" : "None"
            )
            LabeledContent(
                "Protected Action",
                value: model.scene.hasPendingProtectedAction ? "Waiting" : "None"
            )
        }
    }

    private var appActionConfirmation: Binding<Bool> {
        Binding(
            get: { pendingAppAction != nil },
            set: { if !$0 { pendingAppAction = nil } }
        )
    }

    private func perform(_ action: AppWideAction) {
        pendingAppAction = nil
        switch action {
        case .replayOnboarding:
            model.restartOnboarding()
        case let .setMaintenance(enabled):
            model.setMaintenanceEnabled(enabled)
        case .signOut:
            Task { await model.signOut() }
        }
    }

    private var persistenceLabel: String {
        switch model.application.persistenceStatus {
        case .writable: "Writable"
        case .readOnly: "Read-only"
        }
    }

    private var rootLabel: String {
        switch model.application.root {
        case .restoring: "Restoring"
        case .onboarding: "Onboarding"
        case .maintenance: "Maintenance"
        case .main: "Main"
        }
    }

    private var sessionLabel: String {
        switch model.session.session.state {
        case .restoring: "Restoring"
        case .guest: "Guest"
        case .unavailable: "Unavailable"
        case .authenticated: "Authenticated"
        }
    }

    private var restorationLabel: String {
        switch model.scene.restorationResult {
        case .noState: "No Saved State"
        case .restored: "Restored"
        case .migrated: "Migrated"
        case .recovered: "Recovered"
        case .reset: "Reset"
        case .preservedFutureSchema: "Future State Preserved"
        }
    }

    private func dateLabel(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .standard) ?? "Not provided"
    }

    private func pathCount(_ count: Int) -> String {
        count == 0 ? "Root" : "\(count) typed destination\(count == 1 ? "" : "s")"
    }
}

private enum AppWideAction: Equatable {
    case replayOnboarding
    case setMaintenance(Bool)
    case signOut

    var confirmationLabel: String {
        switch self {
        case .replayOnboarding: "Replay Onboarding"
        case let .setMaintenance(enabled):
            enabled ? "Enable Maintenance" : "Disable Maintenance"
        case .signOut: "Sign Out"
        }
    }

    var confirmationMessage: String {
        switch self {
        case .replayOnboarding:
            "This replaces the visible root in every window."
        case .setMaintenance:
            "This changes maintenance policy for every window."
        case .signOut:
            "This signs out the shared application session."
        }
    }

    var role: ButtonRole? {
        switch self {
        case .replayOnboarding, .setMaintenance: nil
        case .signOut: .destructive
        }
    }
}
