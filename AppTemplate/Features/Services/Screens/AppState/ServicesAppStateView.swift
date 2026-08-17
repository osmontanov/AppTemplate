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
        .navigationTitle(AppText.resource("App State"))
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("screen.services.app-state")
        }
        .confirmationDialog(
            AppText.resource("Confirm Application-wide Action"),
            isPresented: appActionConfirmation,
            titleVisibility: .visible,
            presenting: pendingAppAction
        ) { action in
            Button(action.confirmationLabel, role: action.role) {
                perform(action)
            }
            .accessibilityIdentifier("action.services.app-state.confirm")
            Button(AppText.resource("Cancel"), role: .cancel) {}
        } message: { action in
            Text(action.confirmationMessage)
        }
    }

    private var applicationSummary: some View {
        Group {
            Text(AppText.resource("Application"))
                .font(.headline)
            LabeledContent(AppText.resource("Schema"), value: "\(model.application.schemaVersion)")
            LabeledContent(AppText.resource("Persistence"), value: persistenceLabel)
            LabeledContent(AppText.resource("Visible Root"), value: rootLabel)
            LabeledContent(
                AppText.resource("Onboarding Complete"),
                value: model.application.hasCompletedOnboarding
                    ? AppText.string("Yes")
                    : AppText.string("No")
            )
            LabeledContent(
                AppText.resource("Maintenance"),
                value: model.application.isMaintenanceEnabled
                    ? AppText.string("Enabled")
                    : AppText.string("Disabled")
            )
        }
    }

    private var sessionSummary: some View {
        Group {
            Text(AppText.resource("Session"))
                .font(.headline)
            LabeledContent(AppText.resource("State"), value: sessionLabel)
            LabeledContent(AppText.resource("Revision"), value: "\(model.session.session.revision)")
            if let expiry = model.session.expiry {
                LabeledContent(
                    AppText.resource("Access Expiry"),
                    value: dateLabel(expiry.accessExpiresAt)
                )
                LabeledContent(
                    AppText.resource("Refresh Expiry"),
                    value: dateLabel(expiry.refreshExpiresAt)
                )
            }
        }
    }

    private var windowActions: some View {
        Group {
            Text(AppText.resource("Current Window"))
                .font(.headline)
            Button(AppText.resource("Open App Info Sample Link")) {
                model.handleSampleIntent(.openService(.appInfo))
            }
            .accessibilityIdentifier("action.services.app-state.open-app-info")
            Button(AppText.resource("Open Store Sample Link")) {
                model.handleSampleIntent(.openStoreRoot)
            }
            .accessibilityIdentifier("action.services.app-state.open-store")
            Text(AppText.resource("Sample links and Reset Demo Data affect only this window."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appWideActions: some View {
        Group {
            Text(AppText.resource("Application-wide"))
                .font(.headline)
            Button(AppText.resource("Replay Onboarding")) {
                pendingAppAction = .replayOnboarding
            }
            Button(model.application.isMaintenanceEnabled
                ? AppText.string("Disable Maintenance")
                : AppText.string("Enable Maintenance")) {
                pendingAppAction = .setMaintenance(
                    !model.application.isMaintenanceEnabled
                )
            }
            .accessibilityIdentifier("action.services.app-state.maintenance")
            Button(AppText.resource("Sign Out"), role: .destructive) {
                pendingAppAction = .signOut
            }
            Text(AppText.resource("This action affects the entire app."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sceneSummary: some View {
        Group {
            LabeledContent(
                AppText.resource("Selected Section"),
                value: model.scene.selectedSection == .store
                    ? AppText.string("Store")
                    : AppText.string("Services")
            )
            LabeledContent(AppText.resource("Store Path"), value: pathCount(model.scene.storePath.count))
            LabeledContent(
                AppText.resource("Services Path"),
                value: model.scene.servicesPath.isEmpty
                    ? AppText.string("Root")
                    : model.scene.servicesPath.map(\.displayTitle).joined(separator: " → ")
            )
            LabeledContent(AppText.resource("Restoration"), value: restorationLabel)
            LabeledContent(
                AppText.resource("Checkpoint"),
                value: model.scene.checkpoint?.uuidString ?? AppText.string("None")
            )
            LabeledContent(
                AppText.resource("Deferred Link"),
                value: model.scene.hasDeferredLink
                    ? AppText.string("Waiting")
                    : AppText.string("None")
            )
            LabeledContent(
                AppText.resource("Protected Action"),
                value: model.scene.hasPendingProtectedAction
                    ? AppText.string("Waiting")
                    : AppText.string("None")
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
        case .writable: AppText.string("Writable")
        case .readOnly: AppText.string("Read-only")
        }
    }

    private var rootLabel: String {
        switch model.application.root {
        case .restoring: AppText.string("Restoring")
        case .onboarding: AppText.string("Onboarding")
        case .maintenance: AppText.string("Maintenance")
        case .main: AppText.string("Main")
        }
    }

    private var sessionLabel: String {
        switch model.session.session.state {
        case .restoring: AppText.string("Restoring")
        case .guest: AppText.string("Guest")
        case .unavailable: AppText.string("Unavailable")
        case .authenticated: AppText.string("Authenticated")
        }
    }

    private var restorationLabel: String {
        switch model.scene.restorationResult {
        case .noState: AppText.string("No Saved State")
        case .restored: AppText.string("Restored")
        case .migrated: AppText.string("Migrated")
        case .recovered: AppText.string("Recovered")
        case .reset: AppText.string("Reset")
        case .preservedFutureSchema: AppText.string("Future State Preserved")
        }
    }

    private func dateLabel(_ date: Date?) -> String {
        date.map { AppFormatting.dateTime($0, locale: locale, timeZone: timeZone) }
            ?? AppText.string("Not provided")
    }

    private func pathCount(_ count: Int) -> String {
        count == 0
            ? AppText.string("Root")
            : AppText.string(
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
        case .replayOnboarding: AppText.string("Replay Onboarding")
        case let .setMaintenance(enabled):
            enabled
                ? AppText.string("Enable Maintenance")
                : AppText.string("Disable Maintenance")
        case .signOut: AppText.string("Sign Out")
        }
    }

    var confirmationMessage: String {
        switch self {
        case .replayOnboarding:
            AppText.string("This replaces the visible root in every window.")
        case .setMaintenance:
            AppText.string("This changes maintenance policy for every window.")
        case .signOut:
            AppText.string("This signs out the shared application session.")
        }
    }

    var role: ButtonRole? {
        switch self {
        case .replayOnboarding, .setMaintenance: nil
        case .signOut: .destructive
        }
    }
}
