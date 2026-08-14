import SwiftUI

struct KeychainLabView: View {
    private let guide: ServiceLabGuide
    @State private var model: KeychainLabViewModel

    init(
        guide: ServiceLabGuide,
        service: any IKeychainService,
        session: any ISessionActions
    ) {
        self.guide = guide
        _model = State(initialValue: KeychainLabViewModel(
            service: service,
            session: session
        ))
    }

    var body: some View {
        ServiceLabGuideView(
            guide: guide,
            result: model.actualResult,
            resetDemoData: { Task { await model.resetDemoData() } }
        ) {
            operationRow(.string)
            if model.isValueRevealed {
                Button("Hide Value") { model.hideValue() }
            } else {
                Button("Reveal Value") { model.revealValue() }
            }
        } advanced: {
            operationRow(.data)
            operationRow(.codable)
            sessionPanel
            Text("Reveal affects only the current result. Session actions use the session controller and never inspect its stored token data.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Keychain")
        .accessibilityIdentifier("screen.services.keychain")
        .onDisappear { model.hideValue() }
    }

    private func operationRow(_ kind: KeychainLabKind) -> some View {
        VStack(alignment: .leading) {
            Text(kind.title).font(.headline)
            HStack {
                Button("Save") { Task { await model.save(kind) } }
                Button("Read") { Task { await model.read(kind) } }
                Button("Remove") { Task { await model.remove(kind) } }
            }
        }
    }

    private var sessionPanel: some View {
        VStack(alignment: .leading) {
            Text("Application Session").font(.headline)
            LabeledContent("Status", value: sessionStateLabel)
            LabeledContent("Revision", value: "\(model.sessionStatus.session.revision)")
            if let expiry = model.sessionStatus.expiry {
                LabeledContent(
                    "Access Expiry",
                    value: expiryLabel(expiry.accessExpiresAt)
                )
                LabeledContent(
                    "Refresh Expiry",
                    value: expiryLabel(expiry.refreshExpiresAt)
                )
                Text("Expiry dates are server-provided status hints, not local JWT verification or a guaranteed lifetime.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Validate Session") { Task { await model.validateSession() } }
                Button("Refresh Session") { Task { await model.refreshSession() } }
            }
        }
    }

    private var sessionStateLabel: String {
        switch model.sessionStatus.session.state {
        case .restoring: "Restoring"
        case .guest: "Guest"
        case .unavailable: "Unavailable"
        case let .authenticated(profile, availability):
            "Authenticated as \(profile.username) (\(availabilityLabel(availability)))"
        }
    }

    private func availabilityLabel(_ availability: SessionAvailability) -> String {
        switch availability {
        case .validating: "validating"
        case .online: "online"
        case .offline: "offline"
        }
    }

    private func expiryLabel(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .standard) ?? "Not provided"
    }
}
