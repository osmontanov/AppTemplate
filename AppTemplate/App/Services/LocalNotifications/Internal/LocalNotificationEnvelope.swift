import Foundation

nonisolated
struct LocalNotificationEnvelopeV1: Hashable, Codable, Sendable {
    let requestID: LocalNotificationID
    let categoryID: LocalNotificationCategoryID?
    let sound: LocalNotificationSound
    let metadata: [String: LocalNotificationMetadataValue]
    let defaultDeepLink: URL?
    let foregroundPresentation: LocalNotificationForegroundPresentation
    let actionRoutes: [LocalNotificationActionRoute]

    init(
        requestID: LocalNotificationID,
        categoryID: LocalNotificationCategoryID?,
        sound: LocalNotificationSound,
        metadata: [String: LocalNotificationMetadataValue],
        defaultDeepLink: URL?,
        foregroundPresentation: LocalNotificationForegroundPresentation,
        actionRoutes: [LocalNotificationActionRoute]
    ) {
        self.requestID = requestID
        self.categoryID = categoryID
        self.sound = sound
        self.metadata = metadata
        self.defaultDeepLink = defaultDeepLink
        self.foregroundPresentation = foregroundPresentation
        self.actionRoutes = actionRoutes
    }
}

nonisolated
enum LocalNotificationActionRoute: Hashable, Codable, Sendable {
    case button(id: LocalNotificationActionID, deepLink: URL?)
    case textInput(id: LocalNotificationActionID, deepLink: URL?)

    var id: LocalNotificationActionID {
        switch self {
        case let .button(id, _), let .textInput(id, _): id
        }
    }

    var deepLink: URL? {
        switch self {
        case let .button(_, deepLink), let .textInput(_, deepLink): deepLink
        }
    }
}

nonisolated
enum LocalNotificationDecodedEnvelope: Hashable, Sendable {
    case v1(LocalNotificationEnvelopeV1)
}

nonisolated
enum LocalNotificationEnvelopeError: Error, Equatable, Sendable {
    case missingEnvelope
    case corruptEnvelope
    case identifierMismatch
}

nonisolated extension LocalNotificationEnvelopeError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingEnvelope: "Local notification envelope is unavailable."
        case .corruptEnvelope: "Local notification envelope is unreadable."
        case .identifierMismatch: "Local notification envelope does not match its request."
        }
    }
}

nonisolated
enum LocalNotificationEnvelopeCodec {
    static func encode(_ envelope: LocalNotificationEnvelopeV1) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(LocalNotificationEnvelopeWire.v1(envelope))
    }

    static func decode(_ data: Data) throws -> LocalNotificationDecodedEnvelope {
        let decoder = JSONDecoder()
        let version: LocalNotificationEnvelopeSchemaVersion
        do {
            version = try decoder.decode(LocalNotificationEnvelopeSchemaVersion.self, from: data)
        } catch {
            throw LocalNotificationEnvelopeError.corruptEnvelope
        }

        guard version.schemaVersion == 1 else {
            throw LocalNotificationServiceError.unsupportedEnvelopeVersion(version.schemaVersion)
        }

        do {
            let wire = try JSONDecoder().decode(LocalNotificationEnvelopeWire.self, from: data)
            let decoded: LocalNotificationDecodedEnvelope
            switch wire {
            case let .v1(envelope): decoded = .v1(envelope)
            }
            try validateStructural(decoded)
            return decoded
        } catch let error as LocalNotificationServiceError {
            throw error
        } catch {
            throw LocalNotificationEnvelopeError.corruptEnvelope
        }
    }

    static func decodeManaged(
        _ data: Data?,
        physicalRequestID: String,
        namespace: LocalNotificationNamespace,
        deepLinkPolicy: LocalNotificationDeepLinkPolicy
    ) throws -> LocalNotificationEnvelopeV1 {
        guard let data else {
            throw LocalNotificationEnvelopeError.missingEnvelope
        }
        guard let physicalRequestID = namespace.logicalRequestID(physicalRequestID) else {
            throw LocalNotificationEnvelopeError.corruptEnvelope
        }

        let decoded = try decode(data)
        let envelope: LocalNotificationEnvelopeV1
        switch decoded {
        case let .v1(value): envelope = value
        }

        guard envelope.requestID == physicalRequestID else {
            throw LocalNotificationEnvelopeError.identifierMismatch
        }
        try validateDeepLinks(in: envelope, policy: deepLinkPolicy)
        return envelope
    }

    private static func validateStructural(_ decoded: LocalNotificationDecodedEnvelope) throws {
        let envelope: LocalNotificationEnvelopeV1
        switch decoded {
        case let .v1(value): envelope = value
        }

        try LocalNotificationValidator.validate(metadata: .object(envelope.metadata))
        try LocalNotificationValidator.validate(foregroundPresentation: envelope.foregroundPresentation)
        try validate(sound: envelope.sound)

        var actionIDs = Set<LocalNotificationActionID>()
        for actionRoute in envelope.actionRoutes {
            guard actionIDs.insert(actionRoute.id).inserted else {
                throw LocalNotificationEnvelopeError.corruptEnvelope
            }
        }
    }

    private static func validate(sound: LocalNotificationSound) throws {
        guard case let .named(resourceName) = sound else { return }
        guard !resourceName.isEmpty,
              !resourceName.contains("/"),
              !resourceName.contains("\\"),
              !LocalNotificationIdentifierValidator.containsASCIIControl(resourceName) else {
            throw LocalNotificationEnvelopeError.corruptEnvelope
        }
    }

    private static func validateDeepLinks(
        in envelope: LocalNotificationEnvelopeV1,
        policy: LocalNotificationDeepLinkPolicy
    ) throws {
        if let defaultDeepLink = envelope.defaultDeepLink,
           !policy.isValid(defaultDeepLink) {
            throw LocalNotificationServiceError.invalidDeepLink
        }
        for actionRoute in envelope.actionRoutes {
            if let deepLink = actionRoute.deepLink,
               !policy.isValid(deepLink) {
                throw LocalNotificationServiceError.invalidDeepLink
            }
        }
    }
}

nonisolated
private struct LocalNotificationEnvelopeSchemaVersion: Decodable {
    let schemaVersion: Int
}

nonisolated
private enum LocalNotificationEnvelopeWire: Codable {
    case v1(LocalNotificationEnvelopeV1)

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case requestID
        case categoryID
        case sound
        case metadata
        case defaultDeepLink
        case foregroundPresentation
        case actionRoutes
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported local notification envelope version"
            )
        }
        self = .v1(
            LocalNotificationEnvelopeV1(
                requestID: try container.decode(LocalNotificationID.self, forKey: .requestID),
                categoryID: try container.decodeIfPresent(LocalNotificationCategoryID.self, forKey: .categoryID),
                sound: try container.decode(LocalNotificationSound.self, forKey: .sound),
                metadata: try container.decode([String: LocalNotificationMetadataValue].self, forKey: .metadata),
                defaultDeepLink: try container.decodeIfPresent(URL.self, forKey: .defaultDeepLink),
                foregroundPresentation: try container.decode(LocalNotificationForegroundPresentation.self, forKey: .foregroundPresentation),
                actionRoutes: try container.decode([LocalNotificationActionRoute].self, forKey: .actionRoutes)
            )
        )
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case let .v1(envelope):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(1, forKey: .schemaVersion)
            try container.encode(envelope.requestID, forKey: .requestID)
            try container.encodeIfPresent(envelope.categoryID, forKey: .categoryID)
            try container.encode(envelope.sound, forKey: .sound)
            try container.encode(envelope.metadata, forKey: .metadata)
            try container.encodeIfPresent(envelope.defaultDeepLink, forKey: .defaultDeepLink)
            try container.encode(envelope.foregroundPresentation, forKey: .foregroundPresentation)
            try container.encode(envelope.actionRoutes, forKey: .actionRoutes)
        }
    }
}
