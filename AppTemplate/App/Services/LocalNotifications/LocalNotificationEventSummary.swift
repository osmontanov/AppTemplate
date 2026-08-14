import Foundation

nonisolated enum LocalNotificationEventKind: String, Codable, Equatable, Sendable {
    case foreground
    case opened
    case dismissed
    case action
    case textAction
    case diagnostic
}

nonisolated enum LocalNotificationEventStatus: String, Codable, Equatable, Sendable {
    case observed
    case rejected
}

nonisolated enum LocalNotificationEventActionKind: String, Codable, Equatable, Sendable {
    case openProduct
    case favorite
    case remindLater
    case labButton
    case labTextInput
    case unknown
}

nonisolated struct LocalNotificationEventSummary: Equatable, Sendable {
    let kind: LocalNotificationEventKind
    let actionKind: LocalNotificationEventActionKind?
    let status: LocalNotificationEventStatus
    let diagnosticReason: LocalNotificationDiagnosticReason?
    let textInputCharacterCount: Int?

    init(event: LocalNotificationEvent) {
        switch event {
        case .foreground:
            self.init(kind: .foreground)
        case let .opened(notification, _):
            self.init(
                kind: .opened,
                actionKind: Self.isStoreNotification(notification) ? .openProduct : nil
            )
        case .dismissed:
            self.init(kind: .dismissed)
        case let .action(notification, id, _):
            self.init(
                kind: .action,
                actionKind: Self.actionKind(id: id, notification: notification)
            )
        case let .textAction(notification, _, text, _):
            self.init(
                kind: .textAction,
                actionKind: Self.isStoreNotification(notification) ? .unknown : .labTextInput,
                textInputCharacterCount: text.count
            )
        case let .diagnostic(diagnostic):
            self.init(
                kind: .diagnostic,
                status: .rejected,
                diagnosticReason: diagnostic.reason
            )
        }
    }

    init(
        kind: LocalNotificationEventKind,
        actionKind: LocalNotificationEventActionKind? = nil,
        status: LocalNotificationEventStatus = .observed,
        diagnosticReason: LocalNotificationDiagnosticReason? = nil,
        textInputCharacterCount: Int? = nil
    ) {
        self.kind = kind
        self.actionKind = actionKind
        self.status = status
        self.diagnosticReason = diagnosticReason
        self.textInputCharacterCount = textInputCharacterCount
    }

    private static func actionKind(
        id: LocalNotificationActionID,
        notification: LocalNotificationEventNotification
    ) -> LocalNotificationEventActionKind {
        guard isStoreNotification(notification) else { return .labButton }
        if id == AppNotificationIdentifiers.openProductAction { return .openProduct }
        if id == AppNotificationIdentifiers.favoriteAction { return .favorite }
        if id == AppNotificationIdentifiers.remindLaterAction { return .remindLater }
        return .unknown
    }

    private static func isStoreNotification(
        _ notification: LocalNotificationEventNotification
    ) -> Bool {
        guard case let .decoded(request) = notification.payload else { return false }
        return request.content.categoryID == AppNotificationIdentifiers.storeCategory
    }
}

nonisolated struct LocalNotificationEventRecord: Identifiable, Equatable, Sendable {
    let id: UInt64
    let timestamp: Date
    let summary: LocalNotificationEventSummary
}
