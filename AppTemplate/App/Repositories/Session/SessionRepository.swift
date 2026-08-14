import Foundation

actor SessionRepository: ISessionRepository {
    private struct PendingCredentialCandidate: Sendable {
        enum Source: Sendable { case login, refresh }
        let generation: UInt64
        let envelope: StoredSessionEnvelope
        let token: SessionPersistenceRetryToken
        let source: Source
    }

    private struct RefreshFlight: Sendable {
        let generation: UInt64
        let id: UUID
        let task: Task<SessionRepositoryValidationResult, Never>
    }

    private enum MutationFailure: Error {
        case staleGeneration
        case cancelledAfterMutation
    }

    private let remote: any IRemoteService
    private let secureStore: SessionSecureStore
    private let clock: AppClock
    private let refreshLeeway: TimeInterval
    private let credentialMutationGate = AsyncOperationGate()

    private var sessionGeneration: UInt64 = 0
    private var adoptedEnvelope: StoredSessionEnvelope?
    private var credentialsQuarantined = false
    private var activeLoginGeneration: UInt64?
    private var pendingCredentialCandidate: PendingCredentialCandidate?
    private var refreshFlight: RefreshFlight?

    private var activeBootstrapAttemptID: UInt64?
    private var activeBootstrapGeneration: UInt64?
    private var bootstrapCandidate: SessionSecureStoreReadResult?
    private var bootstrapCandidateAttemptID: UInt64?
    private var bootstrapCandidateGeneration: UInt64?

    init(
        remote: any IRemoteService,
        secureStore: SessionSecureStore,
        clock: AppClock = .live,
        refreshLeeway: TimeInterval = 60
    ) {
        self.remote = remote
        self.secureStore = secureStore
        self.clock = clock
        self.refreshLeeway = refreshLeeway
    }

    func beginBootstrapAttempt(_ attemptID: UInt64) {
        activeBootstrapAttemptID = attemptID
        activeBootstrapGeneration = sessionGeneration
        clearBootstrapCandidate()
    }

    func readBootstrapCandidate(
        attemptID: UInt64
    ) async -> SessionBootstrapReadResult {
        let generation = sessionGeneration
        guard activeBootstrapAttemptID == attemptID,
              activeBootstrapGeneration == generation else {
            return .staleAttempt
        }
        do {
            let result = try await secureStore.read()
            guard bootstrapAttemptMatches(attemptID, generation: generation) else {
                return .staleAttempt
            }
            bootstrapCandidate = result
            bootstrapCandidateAttemptID = attemptID
            bootstrapCandidateGeneration = generation
            activeBootstrapAttemptID = nil
            activeBootstrapGeneration = nil
            return .candidateReady
        } catch {
            guard bootstrapAttemptMatches(attemptID, generation: generation) else {
                return .staleAttempt
            }
            bootstrapCandidate = nil
            bootstrapCandidateAttemptID = attemptID
            bootstrapCandidateGeneration = generation
            activeBootstrapAttemptID = nil
            activeBootstrapGeneration = nil
            return .readFailed
        }
    }

    func resolveBootstrapCandidate(
        attemptID: UInt64
    ) async -> SessionRepositorySnapshot {
        guard bootstrapCandidateAttemptID == attemptID,
              bootstrapCandidateGeneration == sessionGeneration,
              !credentialsQuarantined else {
            return readFailureSnapshot
        }
        let generation = sessionGeneration

        switch bootstrapCandidate {
        case .missing:
            clearBootstrapCandidate(attemptID: attemptID)
            adoptedEnvelope = nil
            return guestSnapshot

        case let .envelope(envelope):
            clearBootstrapCandidate(attemptID: attemptID)
            adoptedEnvelope = envelope
            return snapshot(envelope, availability: .validating)

        case .corruptEnvelope:
            do {
                try await removeCredentials(generation: generation)
                guard sessionGeneration == generation else { return readFailureSnapshot }
                clearBootstrapCandidate(attemptID: attemptID)
                adoptedEnvelope = nil
                return guestSnapshot
            } catch is CancellationError {
                return readFailureSnapshot
            } catch MutationFailure.staleGeneration {
                return readFailureSnapshot
            } catch {
                guard sessionGeneration == generation else { return readFailureSnapshot }
                clearBootstrapCandidate(attemptID: attemptID)
                adoptedEnvelope = nil
                credentialsQuarantined = true
                return unavailableCleanupSnapshot
            }

        case .unsupportedSchema, .none:
            clearBootstrapCandidate(attemptID: attemptID)
            return readFailureSnapshot
        }
    }

    func invalidateBootstrapAttempt(_ attemptID: UInt64) -> Bool {
        guard activeBootstrapAttemptID == attemptID else { return false }
        activeBootstrapAttemptID = nil
        activeBootstrapGeneration = nil
        if bootstrapCandidateAttemptID == attemptID { clearBootstrapCandidate() }
        return true
    }

    func login(username: String, password: String) async -> SessionLoginResult {
        guard activeLoginGeneration == nil else {
            return .failure(.concurrentAttempt)
        }
        let previouslyAdoptedEnvelope = adoptedEnvelope
        let generation = advanceGeneration()
        activeLoginGeneration = generation
        let remote = remote
        defer {
            if activeLoginGeneration == generation { activeLoginGeneration = nil }
        }

        let response: AuthSessionDTO
        do {
            try Task.checkCancellation()
            response = try await remote.login(LoginRequestDTO(
                username: username,
                password: password,
                expiresInMins: 30
            ))
            try Task.checkCancellation()
        } catch {
            return loginFailureResult(error)
        }
        guard sessionGeneration == generation else { return .cancelled }
        guard let envelope = envelope(from: response) else {
            return .failure(.responseInvalid)
        }

        let candidate = PendingCredentialCandidate(
            generation: generation,
            envelope: envelope,
            token: SessionPersistenceRetryToken(),
            source: .login
        )
        pendingCredentialCandidate = candidate
        do {
            try await write(candidate)
            guard sessionGeneration == generation, !Task.isCancelled else {
                clearPendingCandidateIfStale()
                return .cancelled
            }
            adoptedEnvelope = envelope
            credentialsQuarantined = false
            pendingCredentialCandidate = nil
            return .authenticated(snapshot(envelope, availability: .online))
        } catch MutationFailure.cancelledAfterMutation {
            await repairCancelledMutation(
                retaining: previouslyAdoptedEnvelope,
                invalidatedGeneration: generation
            )
            return .cancelled
        } catch is CancellationError {
            return .cancelled
        } catch MutationFailure.staleGeneration {
            clearPendingCandidateIfStale()
            return .cancelled
        } catch {
            guard sessionGeneration == generation else {
                clearPendingCandidateIfStale()
                return .cancelled
            }
            return .failure(.persistenceFailed(candidate.token))
        }
    }

    func retryPersistence(
        _ token: SessionPersistenceRetryToken
    ) async -> SessionPersistenceRetryResult {
        guard let candidate = pendingCredentialCandidate else { return .invalidToken }
        guard candidate.generation == sessionGeneration else {
            pendingCredentialCandidate = nil
            return .invalidToken
        }
        guard candidate.token == token else { return .invalidToken }

        do {
            try await write(candidate)
            guard sessionGeneration == candidate.generation, !Task.isCancelled else {
                clearPendingCandidateIfStale()
                return .cancelled
            }
            adoptedEnvelope = candidate.envelope
            credentialsQuarantined = false
            pendingCredentialCandidate = nil
            return .committed(snapshot(candidate.envelope, availability: .online))
        } catch is CancellationError {
            return .cancelled
        } catch MutationFailure.staleGeneration {
            clearPendingCandidateIfStale()
            return .invalidToken
        } catch {
            guard sessionGeneration == candidate.generation else {
                clearPendingCandidateIfStale()
                return .invalidToken
            }
            let replacement = PendingCredentialCandidate(
                generation: candidate.generation,
                envelope: candidate.envelope,
                token: SessionPersistenceRetryToken(),
                source: candidate.source
            )
            pendingCredentialCandidate = replacement
            return .failed(replacement.token, retained: retainedSnapshot(for: candidate))
        }
    }

    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) {
        guard pendingCredentialCandidate?.token == token else { return }
        pendingCredentialCandidate = nil
    }

    func validateStoredSession() async -> SessionRepositoryValidationResult {
        guard !credentialsQuarantined, let envelope = adoptedEnvelope else {
            return .unchanged
        }
        let generation = sessionGeneration
        if let expiry = envelope.accessExpiresAt,
           expiry.timeIntervalSince(clock.now()) <= refreshLeeway {
            return await joinRefresh(generation: generation, envelope: envelope)
        }

        do {
            try Task.checkCancellation()
            let profile = try await remote.me(accessToken: envelope.accessToken)
            try Task.checkCancellation()
            guard sessionGeneration == generation else { return .cancelled }
            guard valid(profile), profile.id == envelope.profile.id,
                  profile.username == envelope.profile.username else {
                return .snapshot(snapshot(envelope, availability: .offline(.responseInvalid)))
            }
            return .snapshot(snapshot(envelope, availability: .online))
        } catch {
            guard sessionGeneration == generation else { return .cancelled }
            return await meFailureResult(error, generation: generation, envelope: envelope)
        }
    }

    func refreshStoredSession() async -> SessionRepositoryValidationResult {
        guard !credentialsQuarantined, let envelope = adoptedEnvelope else {
            return .unchanged
        }
        return await joinRefresh(generation: sessionGeneration, envelope: envelope)
    }

    func signOut() async -> SessionSignOutResult {
        let retainedEnvelope = adoptedEnvelope
        let generation = advanceGeneration()
        do {
            try await removeCredentials(generation: generation)
            guard sessionGeneration == generation, !Task.isCancelled else {
                return .cancelled
            }
            adoptedEnvelope = nil
            credentialsQuarantined = false
            return .guest
        } catch MutationFailure.cancelledAfterMutation {
            await repairCancelledMutation(
                retaining: retainedEnvelope,
                invalidatedGeneration: generation
            )
            adoptedEnvelope = retainedEnvelope
            return .cancelled
        } catch is CancellationError {
            adoptedEnvelope = retainedEnvelope
            return .cancelled
        } catch MutationFailure.staleGeneration {
            return .cancelled
        } catch {
            guard sessionGeneration == generation else { return .cancelled }
            adoptedEnvelope = retainedEnvelope
            return .deletionFailed
        }
    }

    private func joinRefresh(
        generation: UInt64,
        envelope: StoredSessionEnvelope
    ) async -> SessionRepositoryValidationResult {
        guard sessionGeneration == generation, !Task.isCancelled else { return .cancelled }
        let flight: RefreshFlight
        if let existing = refreshFlight, existing.generation == generation {
            flight = existing
        } else {
            let id = UUID()
            let task = Task { [weak self] in
                guard let self else { return SessionRepositoryValidationResult.cancelled }
                return await self.runRefresh(
                    generation: generation,
                    flightID: id,
                    oldEnvelope: envelope
                )
            }
            flight = RefreshFlight(generation: generation, id: id, task: task)
            refreshFlight = flight
        }
        let result = await flight.task.value
        if refreshFlight?.id == flight.id { refreshFlight = nil }
        guard !Task.isCancelled, sessionGeneration == generation || isAuthoritativeResult(result) else {
            return .cancelled
        }
        return result
    }

    private func runRefresh(
        generation: UInt64,
        flightID: UUID,
        oldEnvelope: StoredSessionEnvelope
    ) async -> SessionRepositoryValidationResult {
        do {
            let tokens = try await remote.refresh(RefreshRequestDTO(
                refreshToken: oldEnvelope.refreshToken,
                expiresInMins: 30
            ))
            guard sessionGeneration == generation, !Task.isCancelled else { return .cancelled }
            guard !tokens.accessToken.isEmpty, !tokens.refreshToken.isEmpty else {
                return .snapshot(snapshot(oldEnvelope, availability: .offline(.responseInvalid)))
            }
            let replacement = StoredSessionEnvelope(
                schemaVersion: StoredSessionEnvelope.currentSchemaVersion,
                profile: oldEnvelope.profile,
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                accessExpiresAt: JWTExpiryDecoder.expiryDate(from: tokens.accessToken),
                refreshExpiresAt: JWTExpiryDecoder.expiryDate(from: tokens.refreshToken)
            )
            let candidate = PendingCredentialCandidate(
                generation: generation,
                envelope: replacement,
                token: SessionPersistenceRetryToken(),
                source: .refresh
            )
            pendingCredentialCandidate = candidate
            do {
                try await write(candidate)
                guard sessionGeneration == generation, !Task.isCancelled else {
                    clearPendingCandidateIfStale()
                    return .cancelled
                }
                adoptedEnvelope = replacement
                pendingCredentialCandidate = nil
                return .snapshot(snapshot(replacement, availability: .online))
            } catch is CancellationError {
                return .cancelled
            } catch MutationFailure.staleGeneration {
                clearPendingCandidateIfStale()
                return .cancelled
            } catch {
                guard sessionGeneration == generation else { return .cancelled }
                return .persistenceFailed(
                    snapshot(oldEnvelope, availability: .offline(.secureStorageWriteFailed)),
                    candidate.token
                )
            }
        } catch {
            guard sessionGeneration == generation else { return .cancelled }
            if isCancellation(error) { return .cancelled }
            guard let remoteError = error as? RemoteServiceError else {
                return .snapshot(snapshot(oldEnvelope, availability: .offline(.responseInvalid)))
            }
            let disposition = AuthenticationResponseClassifier.classify(remoteError, endpoint: .refresh)
            if disposition == .credentialsRejected {
                return await rejectCredentials(generation: generation)
            }
            return validationFailure(disposition, retaining: oldEnvelope)
        }
    }

    private func rejectCredentials(generation: UInt64) async -> SessionRepositoryValidationResult {
        guard sessionGeneration == generation else { return .cancelled }
        let cleanupGeneration = advanceGeneration(cancelRefresh: false)
        adoptedEnvelope = nil
        credentialsQuarantined = true
        do {
            try await removeCredentials(generation: cleanupGeneration)
            guard sessionGeneration == cleanupGeneration, !Task.isCancelled else { return .cancelled }
            credentialsQuarantined = false
            return .snapshot(guestSnapshot)
        } catch is CancellationError {
            return .cancelled
        } catch MutationFailure.staleGeneration {
            return .cancelled
        } catch {
            guard sessionGeneration == cleanupGeneration else { return .cancelled }
            return .snapshot(unavailableCleanupSnapshot)
        }
    }

    private func meFailureResult(
        _ error: Error,
        generation: UInt64,
        envelope: StoredSessionEnvelope
    ) async -> SessionRepositoryValidationResult {
        if isCancellation(error) { return .cancelled }
        guard let remoteError = error as? RemoteServiceError else {
            return .snapshot(snapshot(envelope, availability: .offline(.responseInvalid)))
        }
        let disposition = AuthenticationResponseClassifier.classify(remoteError, endpoint: .me)
        if disposition == .refreshRequired {
            return await joinRefresh(generation: generation, envelope: envelope)
        }
        return validationFailure(disposition, retaining: envelope)
    }

    private func validationFailure(
        _ disposition: AuthFailureDisposition,
        retaining envelope: StoredSessionEnvelope
    ) -> SessionRepositoryValidationResult {
        let reason: SessionOfflineReason
        switch disposition {
        case .transport: reason = .transport
        case .serverUnavailable: reason = .serverUnavailable
        case .rateLimited: reason = .rateLimited
        case .cancelled: return .cancelled
        case .invalidCredentials, .refreshRequired, .credentialsRejected, .responseInvalid:
            reason = .responseInvalid
        }
        return .snapshot(snapshot(envelope, availability: .offline(reason)))
    }

    private func performAuthenticated(
        operation: @Sendable (String) async throws -> UserProfileDTO
    ) async -> SessionRepositoryValidationResult {
        guard let envelope = adoptedEnvelope, !credentialsQuarantined else { return .unchanged }
        let generation = sessionGeneration
        do {
            _ = try await operation(envelope.accessToken)
            guard sessionGeneration == generation else { return .cancelled }
            return .snapshot(snapshot(envelope, availability: .online))
        } catch let error as RemoteServiceError
            where AuthenticationResponseClassifier.classify(error, endpoint: .me) == .refreshRequired {
            let refreshed = await joinRefresh(generation: generation, envelope: envelope)
            guard case .snapshot = refreshed,
                  let replacement = adoptedEnvelope,
                  sessionGeneration != generation || replacement.accessToken != envelope.accessToken else {
                return refreshed
            }
            do {
                _ = try await operation(replacement.accessToken)
                return .snapshot(snapshot(replacement, availability: .online))
            } catch {
                return validationFailureForSemantic(error, retaining: replacement)
            }
        } catch {
            return validationFailureForSemantic(error, retaining: envelope)
        }
    }

#if DEBUG
    func authenticatedOperationProbeForTesting() async -> SessionRepositoryValidationResult {
        let remote = remote
        return await performAuthenticated { token in
            try await remote.me(accessToken: token)
        }
    }
#endif

    private func validationFailureForSemantic(
        _ error: Error,
        retaining envelope: StoredSessionEnvelope
    ) -> SessionRepositoryValidationResult {
        guard let remoteError = error as? RemoteServiceError else {
            return .snapshot(snapshot(envelope, availability: .offline(.responseInvalid)))
        }
        return validationFailure(
            AuthenticationResponseClassifier.classify(remoteError, endpoint: .me),
            retaining: envelope
        )
    }

    private func write(_ candidate: PendingCredentialCandidate) async throws {
        let generation = candidate.generation
        let secureStore = secureStore
        try await credentialMutationGate.withExclusiveAccess { [weak self] in
            guard let self, await self.sessionGeneration == generation else {
                throw MutationFailure.staleGeneration
            }
            try Task.checkCancellation()
            try await secureStore.write(candidate.envelope)
            if Task.isCancelled { throw MutationFailure.cancelledAfterMutation }
            guard await self.sessionGeneration == generation else {
                throw MutationFailure.staleGeneration
            }
        }
    }

    private func removeCredentials(generation: UInt64) async throws {
        let secureStore = secureStore
        try await credentialMutationGate.withExclusiveAccess { [weak self] in
            guard let self, await self.sessionGeneration == generation else {
                throw MutationFailure.staleGeneration
            }
            try Task.checkCancellation()
            _ = try await secureStore.remove()
            if Task.isCancelled { throw MutationFailure.cancelledAfterMutation }
            guard await self.sessionGeneration == generation else {
                throw MutationFailure.staleGeneration
            }
        }
    }

    @discardableResult
    private func advanceGeneration(cancelRefresh: Bool = true) -> UInt64 {
        sessionGeneration &+= 1
        if cancelRefresh { refreshFlight?.task.cancel() }
        refreshFlight = nil
        pendingCredentialCandidate = nil
        activeBootstrapAttemptID = nil
        activeBootstrapGeneration = nil
        clearBootstrapCandidate()
        return sessionGeneration
    }

    private func envelope(from response: AuthSessionDTO) -> StoredSessionEnvelope? {
        guard response.id > 0,
              !response.username.isEmpty,
              !response.firstName.isEmpty,
              !response.lastName.isEmpty,
              !response.accessToken.isEmpty,
              !response.refreshToken.isEmpty else { return nil }
        return StoredSessionEnvelope(
            schemaVersion: StoredSessionEnvelope.currentSchemaVersion,
            profile: UserProfile(
                id: response.id,
                username: response.username,
                firstName: response.firstName,
                lastName: response.lastName,
                imageURL: response.image
            ),
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            accessExpiresAt: JWTExpiryDecoder.expiryDate(from: response.accessToken),
            refreshExpiresAt: JWTExpiryDecoder.expiryDate(from: response.refreshToken)
        )
    }

    private func valid(_ profile: UserProfileDTO) -> Bool {
        profile.id > 0 && !profile.username.isEmpty &&
            !profile.firstName.isEmpty && !profile.lastName.isEmpty
    }

    private func loginFailureResult(_ error: Error) -> SessionLoginResult {
        if isCancellation(error) { return .cancelled }
        guard let remoteError = error as? RemoteServiceError else {
            return .failure(.responseInvalid)
        }
        switch AuthenticationResponseClassifier.classify(remoteError, endpoint: .login) {
        case .invalidCredentials: return .failure(.invalidCredentials)
        case .transport: return .failure(.transport)
        case .serverUnavailable: return .failure(.serverUnavailable)
        case .rateLimited: return .failure(.rateLimited)
        case .cancelled: return .cancelled
        case .refreshRequired, .credentialsRejected, .responseInvalid:
            return .failure(.responseInvalid)
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? RemoteServiceError) == .cancelled
    }

    private func snapshot(
        _ envelope: StoredSessionEnvelope,
        availability: SessionAvailability
    ) -> SessionRepositorySnapshot {
        SessionRepositorySnapshot(
            state: .authenticated(envelope.profile, availability: availability),
            expiry: SessionExpiryPresentation(
                accessExpiresAt: envelope.accessExpiresAt,
                refreshExpiresAt: envelope.refreshExpiresAt
            )
        )
    }

    private func retainedSnapshot(
        for candidate: PendingCredentialCandidate
    ) -> SessionRepositorySnapshot {
        switch candidate.source {
        case .login:
            guard let adoptedEnvelope else { return guestSnapshot }
            return snapshot(adoptedEnvelope, availability: .online)
        case .refresh:
            guard let adoptedEnvelope else { return guestSnapshot }
            return snapshot(adoptedEnvelope, availability: .offline(.secureStorageWriteFailed))
        }
    }

    private var guestSnapshot: SessionRepositorySnapshot {
        SessionRepositorySnapshot(state: .guest, expiry: nil)
    }

    private var unavailableCleanupSnapshot: SessionRepositorySnapshot {
        SessionRepositorySnapshot(
            state: .unavailable(.secureStorageCleanupFailed),
            expiry: nil
        )
    }

    private var readFailureSnapshot: SessionRepositorySnapshot {
        SessionRepositorySnapshot(
            state: .unavailable(.secureStorageReadFailed),
            expiry: nil
        )
    }

    private func bootstrapAttemptMatches(_ attemptID: UInt64, generation: UInt64) -> Bool {
        activeBootstrapAttemptID == attemptID &&
            activeBootstrapGeneration == generation &&
            sessionGeneration == generation
    }

    private func clearBootstrapCandidate(attemptID: UInt64? = nil) {
        if let attemptID, bootstrapCandidateAttemptID != attemptID { return }
        bootstrapCandidate = nil
        bootstrapCandidateAttemptID = nil
        bootstrapCandidateGeneration = nil
    }

    private func clearPendingCandidateIfStale() {
        guard pendingCredentialCandidate?.generation != sessionGeneration else { return }
        pendingCredentialCandidate = nil
    }

    private func repairCancelledMutation(
        retaining envelope: StoredSessionEnvelope?,
        invalidatedGeneration: UInt64
    ) async {
        guard sessionGeneration == invalidatedGeneration else { return }
        let repairGeneration = advanceGeneration()
        let repairTask = Task.detached { [weak self] in
            await self?.performCredentialRepair(
                retaining: envelope,
                generation: repairGeneration
            )
        }
        await repairTask.value
    }

    private func performCredentialRepair(
        retaining envelope: StoredSessionEnvelope?,
        generation: UInt64
    ) async {
        let secureStore = secureStore
        try? await credentialMutationGate.withExclusiveAccess { [weak self] in
            guard let self, await self.sessionGeneration == generation else {
                throw MutationFailure.staleGeneration
            }
            if let envelope {
                try await secureStore.write(envelope)
            } else {
                _ = try await secureStore.remove()
            }
        }
    }

    private func isAuthoritativeResult(_ result: SessionRepositoryValidationResult) -> Bool {
        switch result {
        case .snapshot(let value):
            return value.state == .guest || value.state == .unavailable(.secureStorageCleanupFailed)
        default:
            return false
        }
    }
}
