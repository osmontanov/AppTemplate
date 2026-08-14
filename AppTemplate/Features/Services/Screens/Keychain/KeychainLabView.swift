import SwiftUI

struct KeychainLabView: View {
    private let guide: ServiceLabGuide
    @State private var model: KeychainLabViewModel
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

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
                Button(StoreServicesText.resource("Hide Value")) { model.hideValue() }
            } else {
                Button(StoreServicesText.resource("Reveal Value")) { model.revealValue() }
            }
        } advanced: {
            operationRow(.data)
            operationRow(.codable)
            sessionPanel
            Text(StoreServicesText.resource("Reveal affects only the current result. Session actions use the session controller and never inspect its stored token data."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(StoreServicesText.resource("Keychain"))
        .accessibilityIdentifier("screen.services.keychain")
        .onDisappear { model.hideValue() }
    }

    private func operationRow(_ kind: KeychainLabKind) -> some View {
        VStack(alignment: .leading) {
            Text(kind.title).font(.headline)
            HStack {
                Button(StoreServicesText.resource("Save")) { Task { await model.save(kind) } }
                Button(StoreServicesText.resource("Read")) { Task { await model.read(kind) } }
                Button(StoreServicesText.resource("Remove")) { Task { await model.remove(kind) } }
            }
        }
    }

    private var sessionPanel: some View {
        VStack(alignment: .leading) {
            Text(StoreServicesText.resource("Application Session")).font(.headline)
            LabeledContent(StoreServicesText.resource("Status"), value: sessionStateLabel)
            LabeledContent(StoreServicesText.resource("Revision"), value: "\(model.sessionStatus.session.revision)")
            if let expiry = model.sessionStatus.expiry {
                LabeledContent(
                    StoreServicesText.resource("Access Expiry"),
                    value: expiryLabel(expiry.accessExpiresAt)
                )
                LabeledContent(
                    StoreServicesText.resource("Refresh Expiry"),
                    value: expiryLabel(expiry.refreshExpiresAt)
                )
                Text(StoreServicesText.resource("Expiry dates are server-provided status hints, not local JWT verification or a guaranteed lifetime."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button(StoreServicesText.resource("Validate Session")) { Task { await model.validateSession() } }
                Button(StoreServicesText.resource("Refresh Session")) { Task { await model.refreshSession() } }
            }
        }
    }

    private var sessionStateLabel: String {
        switch model.sessionStatus.session.state {
        case .restoring: StoreServicesText.string("Restoring")
        case .guest: StoreServicesText.string("Guest")
        case .unavailable: StoreServicesText.string("Unavailable")
        case let .authenticated(profile, availability):
            StoreServicesText.string(
                "services.keychain.authenticated",
                defaultValue: "Authenticated as \(profile.username) (\(availabilityLabel(availability)))"
            )
        }
    }

    private func availabilityLabel(_ availability: SessionAvailability) -> String {
        switch availability {
        case .validating: StoreServicesText.string("validating")
        case .online: StoreServicesText.string("online")
        case .offline: StoreServicesText.string("offline")
        }
    }

    private func expiryLabel(_ date: Date?) -> String {
        date.map { StoreFormatting.dateTime($0, locale: locale, timeZone: timeZone) }
            ?? StoreServicesText.string("Not provided")
    }
}
