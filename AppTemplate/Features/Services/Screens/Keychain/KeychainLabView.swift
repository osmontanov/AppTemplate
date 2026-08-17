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
                Button(AppText.resource("Hide Value")) { model.hideValue() }
            } else {
                Button(AppText.resource("Reveal Value")) { model.revealValue() }
            }
        } advanced: {
            operationRow(.data)
            operationRow(.codable)
            sessionPanel
            Text(AppText.resource("Reveal affects only the current result. Session actions use the session controller and never inspect its stored token data."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(AppText.resource("Keychain"))
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("screen.services.keychain")
        }
        .onDisappear { model.hideValue() }
    }

    @ViewBuilder
    private func operationRow(_ kind: KeychainLabKind) -> some View {
        VStack(alignment: .leading) {
            Text(kind.title).font(.headline)
            HStack {
                if kind == .string {
                    Button(AppText.resource("Save")) { Task { await model.save(kind) } }
                        .accessibilityIdentifier(AppAccessibilityIdentifier.action(.tryService))
                } else {
                    Button(AppText.resource("Save")) { Task { await model.save(kind) } }
                }
                Button(AppText.resource("Read")) { Task { await model.read(kind) } }
                Button(AppText.resource("Remove")) { Task { await model.remove(kind) } }
            }
        }
    }

    private var sessionPanel: some View {
        VStack(alignment: .leading) {
            Text(AppText.resource("Application Session")).font(.headline)
            LabeledContent(AppText.resource("Status"), value: sessionStateLabel)
            LabeledContent(AppText.resource("Revision"), value: "\(model.sessionStatus.session.revision)")
            if let expiry = model.sessionStatus.expiry {
                LabeledContent(
                    AppText.resource("Access Expiry"),
                    value: expiryLabel(expiry.accessExpiresAt)
                )
                LabeledContent(
                    AppText.resource("Refresh Expiry"),
                    value: expiryLabel(expiry.refreshExpiresAt)
                )
                Text(AppText.resource("Expiry dates are server-provided status hints, not local JWT verification or a guaranteed lifetime."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button(AppText.resource("Validate Session")) { Task { await model.validateSession() } }
                Button(AppText.resource("Refresh Session")) { Task { await model.refreshSession() } }
            }
        }
    }

    private var sessionStateLabel: String {
        switch model.sessionStatus.session.state {
        case .restoring: AppText.string("Restoring")
        case .guest: AppText.string("Guest")
        case .unavailable: AppText.string("Unavailable")
        case let .authenticated(profile, availability):
            AppText.string(
                "services.keychain.authenticated",
                defaultValue: "Authenticated as \(profile.username) (\(availabilityLabel(availability)))"
            )
        }
    }

    private func availabilityLabel(_ availability: SessionAvailability) -> String {
        switch availability {
        case .validating: AppText.string("validating")
        case .online: AppText.string("online")
        case .offline: AppText.string("offline")
        }
    }

    private func expiryLabel(_ date: Date?) -> String {
        date.map { AppFormatting.dateTime($0, locale: locale, timeZone: timeZone) }
            ?? AppText.string("Not provided")
    }
}
