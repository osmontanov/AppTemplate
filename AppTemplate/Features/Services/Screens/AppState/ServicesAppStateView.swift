import SwiftUI

struct ServicesAppStateView: View {
    private let guide: ServiceLabGuide
    @State private var model: ServicesAppStateViewModel
    @State private var pendingAppAction: AppWideAction?
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

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
        .navigationTitle(StoreServicesText.resource("App State"))
        .accessibilityIdentifier("screen.services.app-state")
        .confirmationDialog(
            StoreServicesText.resource("Confirm Application-wide Action"),
            isPresented: appActionConfirmation,
            titleVisibility: .visible,
            presenting: pendingAppAction
        ) { action in
            Button(action.confirmationLabel, role: action.role) {
                perform(action)
            }
            Button(StoreServicesText.resource("Cancel"), role: .cancel) {}
        } message: { action in
            Text(action.confirmationMessage)
        }
    }

    private var applicationSummary: some View {
        Group {
            Text(StoreServicesText.resource("Application"))
                .font(.headline)
            LabeledContent(StoreServicesText.resource("Schema"), value: "\(model.application.schemaVersion)")
            LabeledContent(StoreServicesText.resource("Persistence"), value: persistenceLabel)
            LabeledContent(StoreServicesText.resource("Visible Root"), value: rootLabel)
            LabeledContent(
                StoreServicesText.resource("Onboarding Complete"),
                value: model.application.hasCompletedOnboarding
                    ? StoreServicesText.string("Yes")
                    : StoreServicesText.string("No")
            )
            LabeledContent(
                StoreServicesText.resource("Maintenance"),
                value: model.application.isMaintenanceEnabled
                    ? StoreServicesText.string("Enabled")
                    : StoreServicesText.string("Disabled")
            )
        }
    }

    private var sessionSummary: some View {
        Group {
            Text(StoreServicesText.resource("Session"))
                .font(.headline)
            LabeledContent(StoreServicesText.resource("State"), value: sessionLabel)
            LabeledContent(StoreServicesText.resource("Revision"), value: "\(model.session.session.revision)")
            if let expiry = model.session.expiry {
                LabeledContent(
                    StoreServicesText.resource("Access Expiry"),
                    value: dateLabel(expiry.accessExpiresAt)
                )
                LabeledContent(
                    StoreServicesText.resource("Refresh Expiry"),
                    value: dateLabel(expiry.refreshExpiresAt)
                )
            }
        }
    }

    private var windowActions: some View {
        Group {
            Text(StoreServicesText.resource("Current Window"))
                .font(.headline)
            Button(StoreServicesText.resource("Open App Info Sample Link")) {
                model.handleSampleIntent(.openService(.appInfo))
            }
            Button(StoreServicesText.resource("Open Store Sample Link")) {
                model.handleSampleIntent(.openStoreRoot)
            }
            Text(StoreServicesText.resource("Sample links and Reset Demo Data affect only this window."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appWideActions: some View {
        Group {
            Text(StoreServicesText.resource("Application-wide"))
                .font(.headline)
            Button(StoreServicesText.resource("Replay Onboarding")) {
                pendingAppAction = .replayOnboarding
            }
            Button(model.application.isMaintenanceEnabled
                ? StoreServicesText.string("Disable Maintenance")
                : StoreServicesText.string("Enable Maintenance")) {
                pendingAppAction = .setMaintenance(
                    !model.application.isMaintenanceEnabled
                )
            }
            Button(StoreServicesText.resource("Sign Out"), role: .destructive) {
                pendingAppAction = .signOut
            }
            Text(StoreServicesText.resource(.appWideImpact))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sceneSummary: some View {
        Group {
            LabeledContent(
                StoreServicesText.resource("Selected Section"),
                value: model.scene.selectedSection == .store
                    ? StoreServicesText.string("Store")
                    : StoreServicesText.string("Services")
            )
            LabeledContent(StoreServicesText.resource("Store Path"), value: pathCount(model.scene.storePath.count))
            LabeledContent(
                StoreServicesText.resource("Services Path"),
                value: model.scene.servicesPath.isEmpty
                    ? StoreServicesText.string("Root")
                    : model.scene.servicesPath.map(\.displayTitle).joined(separator: " → ")
            )
            LabeledContent(StoreServicesText.resource("Restoration"), value: restorationLabel)
            LabeledContent(
                StoreServicesText.resource("Checkpoint"),
                value: model.scene.checkpoint?.uuidString ?? StoreServicesText.string("None")
            )
            LabeledContent(
                StoreServicesText.resource("Deferred Link"),
                value: model.scene.hasDeferredLink
                    ? StoreServicesText.string("Waiting")
                    : StoreServicesText.string("None")
            )
            LabeledContent(
                StoreServicesText.resource("Protected Action"),
                value: model.scene.hasPendingProtectedAction
                    ? StoreServicesText.string("Waiting")
                    : StoreServicesText.string("None")
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
        case .writable: StoreServicesText.string("Writable")
        case .readOnly: StoreServicesText.string("Read-only")
        }
    }

    private var rootLabel: String {
        switch model.application.root {
        case .restoring: StoreServicesText.string("Restoring")
        case .onboarding: StoreServicesText.string("Onboarding")
        case .maintenance: StoreServicesText.string("Maintenance")
        case .main: StoreServicesText.string("Main")
        }
    }

    private var sessionLabel: String {
        switch model.session.session.state {
        case .restoring: StoreServicesText.string("Restoring")
        case .guest: StoreServicesText.string("Guest")
        case .unavailable: StoreServicesText.string("Unavailable")
        case .authenticated: StoreServicesText.string("Authenticated")
        }
    }

    private var restorationLabel: String {
        switch model.scene.restorationResult {
        case .noState: StoreServicesText.string("No Saved State")
        case .restored: StoreServicesText.string("Restored")
        case .migrated: StoreServicesText.string("Migrated")
        case .recovered: StoreServicesText.string("Recovered")
        case .reset: StoreServicesText.string("Reset")
        case .preservedFutureSchema: StoreServicesText.string("Future State Preserved")
        }
    }

    private func dateLabel(_ date: Date?) -> String {
        date.map { StoreFormatting.dateTime($0, locale: locale, timeZone: timeZone) }
            ?? StoreServicesText.string("Not provided")
    }

    private func pathCount(_ count: Int) -> String {
        count == 0
            ? StoreServicesText.string("Root")
            : StoreServicesText.string(
                "services.appState.pathCount",
                defaultValue: "\(count) typed destinations"
            )
    }
}

private enum AppWideAction: Equatable {
    case replayOnboarding
    case setMaintenance(Bool)
    case signOut

    var confirmationLabel: String {
        switch self {
        case .replayOnboarding: StoreServicesText.string("Replay Onboarding")
        case let .setMaintenance(enabled):
            enabled
                ? StoreServicesText.string("Enable Maintenance")
                : StoreServicesText.string("Disable Maintenance")
        case .signOut: StoreServicesText.string("Sign Out")
        }
    }

    var confirmationMessage: String {
        switch self {
        case .replayOnboarding:
            StoreServicesText.string("This replaces the visible root in every window.")
        case .setMaintenance:
            StoreServicesText.string("This changes maintenance policy for every window.")
        case .signOut:
            StoreServicesText.string("This signs out the shared application session.")
        }
    }

    var role: ButtonRole? {
        switch self {
        case .replayOnboarding, .setMaintenance: nil
        case .signOut: .destructive
        }
    }
}
