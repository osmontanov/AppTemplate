import Foundation
import Observation

@MainActor
@Observable
final class KeychainLabViewModel {
    private static let maximumDataBytes = 4_096
    private static let maximumHexCharacters = 8_192
    private static let maximumStringBytes = 4_096

    private let service: any IKeychainService
    private let session: any ISessionActions
    private var maskedMessage: String?
    private var revealedMessage: String?

    private(set) var actualResult: ServiceLabResult = .idle
    private(set) var isValueRevealed = false

    init(service: any IKeychainService, session: any ISessionActions) {
        self.service = service
        self.session = session
    }

    var sessionStatus: SessionStatusPresentation { session.status }

    func revealValue() {
        guard let revealedMessage else { return }
        isValueRevealed = true
        actualResult = .success(revealedMessage)
    }

    func hideValue() {
        isValueRevealed = false
        if let maskedMessage { actualResult = .success(maskedMessage) }
    }

    func save(_ kind: KeychainLabKind) async {
        beginOperation()
        do {
            switch kind {
            case .data:
                try await service.set(KeychainLabFixtures.data, for: KeychainLabKeys.data)
                publishSecret(kind, presentation: hexPresentation(KeychainLabFixtures.data))
            case .string:
                try await service.set(KeychainLabFixtures.string, for: KeychainLabKeys.string)
                publishSecret(kind, presentation: KeychainLabFixtures.string)
            case .codable:
                try await service.set(KeychainLabFixtures.codable, for: KeychainLabKeys.codable)
                publishSecret(kind, presentation: codablePresentation(KeychainLabFixtures.codable))
            }
        } catch is CancellationError {
            fail(AppText.string("The secure-storage operation was cancelled."))
        } catch {
            fail(AppText.string("The secure demo value could not be saved."))
        }
    }

    func read(_ kind: KeychainLabKind) async {
        beginOperation()
        do {
            switch kind {
            case .data:
                guard let data = try await service.data(for: KeychainLabKeys.data) else {
                    publishMissing(kind)
                    return
                }
                guard data.count <= Self.maximumDataBytes else {
                    fail(AppText.string("Secure data exceeds the 4,096-byte display limit."))
                    return
                }
                publishSecret(kind, presentation: hexPresentation(data))
            case .string:
                guard let value = try await service.string(for: KeychainLabKeys.string) else {
                    publishMissing(kind)
                    return
                }
                guard value.utf8.count <= Self.maximumStringBytes else {
                    fail(AppText.string("The secure string exceeds the display limit."))
                    return
                }
                publishSecret(kind, presentation: value)
            case .codable:
                guard let value = try await service.value(for: KeychainLabKeys.codable) else {
                    publishMissing(kind)
                    return
                }
                guard value.label.utf8.count <= Self.maximumStringBytes else {
                    fail(AppText.string("The secure model exceeds the display limit."))
                    return
                }
                publishSecret(kind, presentation: codablePresentation(value))
            }
        } catch is CancellationError {
            fail(AppText.string("The secure-storage operation was cancelled."))
        } catch {
            fail(AppText.string("The secure demo value could not be read."))
        }
    }

    func remove(_ kind: KeychainLabKind) async {
        beginOperation()
        do {
            switch kind {
            case .data: _ = try await service.remove(KeychainLabKeys.data)
            case .string: _ = try await service.remove(KeychainLabKeys.string)
            case .codable: _ = try await service.remove(KeychainLabKeys.codable)
            }
            actualResult = .success(AppText.string("Removed \(kind.title)."))
        } catch is CancellationError {
            fail(AppText.string("The secure-storage operation was cancelled."))
        } catch {
            fail(AppText.string("The secure demo value could not be removed."))
        }
    }

    func resetDemoData() async {
        beginOperation()
        do {
            _ = try await service.remove(KeychainLabKeys.data)
            _ = try await service.remove(KeychainLabKeys.string)
            _ = try await service.remove(KeychainLabKeys.codable)
            actualResult = .success(AppText.string("Reset only the three Keychain demo values."))
        } catch is CancellationError {
            fail(AppText.string("The secure-storage operation was cancelled."))
        } catch {
            fail(AppText.string("The secure demo values could not be reset."))
        }
    }

    func validateSession() async {
        beginOperation()
        actualResult = map(
            await session.validateSession(),
            operation: AppText.string("Session validation")
        )
    }

    func refreshSession() async {
        beginOperation()
        actualResult = map(
            await session.refreshSession(),
            operation: AppText.string("Session refresh")
        )
    }

    private func beginOperation() {
        clearSecretPresentation()
        actualResult = .running
    }

    private func clearSecretPresentation() {
        isValueRevealed = false
        maskedMessage = nil
        revealedMessage = nil
    }

    private func publishSecret(_ kind: KeychainLabKind, presentation: String) {
        let masked = AppText.string("\(kind.title): masked")
        maskedMessage = masked
        revealedMessage = AppText.string(
            "services.keychain.revealedValue",
            defaultValue: "\(kind.title): \(presentation)"
        )
        actualResult = .success(masked)
    }

    private func publishMissing(_ kind: KeychainLabKind) {
        actualResult = .success(AppText.string("\(kind.title): no value stored."))
    }

    private func fail(_ message: String) {
        clearSecretPresentation()
        actualResult = .failure(message)
    }

    private func hexPresentation(_ data: Data) -> String {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(Self.maximumHexCharacters))
    }

    private func codablePresentation(_ value: KeychainLabCodable) -> String {
        AppText.string(
            "services.keychain.codableValue",
            defaultValue: "number \(value.number), label \(value.label)"
        )
    }

    private func map(
        _ result: SessionValidationResult,
        operation: String
    ) -> ServiceLabResult {
        switch result {
        case .committed:
            .success(AppText.string("\(operation) updated the session status."))
        case .persistenceFailed:
            .failure(AppText.string("\(operation) completed but could not save secure session data."))
        case .unchanged:
            .success(AppText.string("\(operation) completed with no status change."))
        case .failed:
            .failure(AppText.string("\(operation) could not complete."))
        case .cancelled:
            .failure(AppText.string("\(operation) was cancelled."))
        }
    }
}
