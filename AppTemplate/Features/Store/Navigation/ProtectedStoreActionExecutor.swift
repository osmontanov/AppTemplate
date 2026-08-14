import Foundation
import Observation

nonisolated
enum ProtectedStoreActionExecutionError: Equatable, Sendable {
    case productLoadFailed
    case favoriteReadFailed
    case favoriteWriteFailed
}

@MainActor
@Observable
final class ProtectedStoreActionExecutor {
    private let router: StoreRouter
    private let products: any IProductRepository
    private let favorites: any IFavoritesRepository
    private let session: any ISessionActions
    private var identityGeneration: UInt64 = 0
    private var observedUserID: Int?
    private(set) var error: ProtectedStoreActionExecutionError?

    init(
        router: StoreRouter,
        products: any IProductRepository,
        favorites: any IFavoritesRepository,
        session: any ISessionActions
    ) {
        self.router = router
        self.products = products
        self.favorites = favorites
        self.session = session
        if case let .authenticated(profile, _) = session.presentation.state {
            observedUserID = profile.id
        }
    }

    func activateHeart(for product: Product, session state: SessionState) async {
        switch router.requestProtected(.favorite(product.id), session: state) {
        case .presentAuthentication:
            return
        case let .blocked(reason):
            router.presentation = .sessionRecovery(reason)
        case .execute:
            guard case let .authenticated(profile, _) = state else { return }
            await toggleHeart(product, expectedUserID: profile.id)
        }
    }

    func activateHeart(productID: Product.ID, session state: SessionState) async {
        switch router.requestProtected(.favorite(productID), session: state) {
        case .presentAuthentication:
            return
        case let .blocked(reason):
            router.presentation = .sessionRecovery(reason)
        case .execute:
            guard case let .authenticated(profile, _) = state else { return }
            let generation = identityGeneration
            let product: Product
            do {
                product = try await products.product(id: productID)
            } catch is CancellationError {
                return
            } catch {
                publish(.productLoadFailed, userID: profile.id, generation: generation)
                return
            }
            guard isCurrent(userID: profile.id, generation: generation) else { return }
            await toggleHeart(product, expectedUserID: profile.id, generation: generation)
        }
    }

    func execute(_ action: ProtectedStoreAction, expectedUserID: Int) async {
        let generation = identityGeneration
        guard isCurrent(userID: expectedUserID, generation: generation) else { return }
        switch action {
        case let .favorite(id):
            let product: Product
            do {
                product = try await products.product(id: id)
            } catch is CancellationError {
                return
            } catch {
                publish(.productLoadFailed, userID: expectedUserID, generation: generation)
                return
            }
            guard isCurrent(userID: expectedUserID, generation: generation) else { return }
            do {
                guard isCurrent(userID: expectedUserID, generation: generation) else { return }
                _ = try await favorites.ensureFavorite(
                    product.snapshot,
                    userID: expectedUserID
                )
                guard isCurrent(userID: expectedUserID, generation: generation) else { return }
                error = nil
            } catch is CancellationError {
                return
            } catch {
                publish(.favoriteWriteFailed, userID: expectedUserID, generation: generation)
            }
        case .openFavorites:
            guard isCurrent(userID: expectedUserID, generation: generation) else { return }
            router.replace(with: .favorites)
        case .openAccount:
            guard isCurrent(userID: expectedUserID, generation: generation) else { return }
            _ = router.selectProfileSection(
                .account,
                session: session.presentation.state
            )
            if case let .authenticated(profile, availability) = session.presentation.state,
               profile.id == expectedUserID {
                router.cacheAccountPresentation(ProfileAccountPresentation(
                    userID: profile.id,
                    displayName: Self.displayName(profile),
                    availability: availability
                ))
            }
        }
    }

    func sessionDidChange(_ presentation: SessionPresentation) {
        switch presentation.state {
        case let .authenticated(profile, _):
            if let observedUserID, observedUserID != profile.id {
                invalidate()
            }
            observedUserID = profile.id
        case .guest, .unavailable:
            invalidate()
            observedUserID = nil
        case .restoring:
            break
        }
    }

    private func toggleHeart(
        _ product: Product,
        expectedUserID: Int,
        generation: UInt64? = nil
    ) async {
        let generation = generation ?? identityGeneration
        guard isCurrent(userID: expectedUserID, generation: generation) else { return }
        let isFavorite: Bool
        do {
            isFavorite = try await favorites.contains(
                userID: expectedUserID,
                productID: product.id
            )
        } catch is CancellationError {
            return
        } catch {
            publish(.favoriteReadFailed, userID: expectedUserID, generation: generation)
            return
        }
        guard isCurrent(userID: expectedUserID, generation: generation) else { return }
        do {
            guard isCurrent(userID: expectedUserID, generation: generation) else { return }
            if isFavorite {
                _ = try await favorites.removeFavorite(
                    userID: expectedUserID,
                    productID: product.id
                )
            } else {
                _ = try await favorites.ensureFavorite(
                    product.snapshot,
                    userID: expectedUserID
                )
            }
            guard isCurrent(userID: expectedUserID, generation: generation) else { return }
            error = nil
        } catch is CancellationError {
            return
        } catch {
            publish(.favoriteWriteFailed, userID: expectedUserID, generation: generation)
        }
    }

    private func isCurrent(userID: Int, generation: UInt64) -> Bool {
        guard generation == identityGeneration,
              case let .authenticated(profile, _) = session.presentation.state,
              profile.id == userID else {
            return false
        }
        return true
    }

    private func publish(
        _ value: ProtectedStoreActionExecutionError,
        userID: Int,
        generation: UInt64
    ) {
        guard isCurrent(userID: userID, generation: generation) else { return }
        error = value
    }

    private func invalidate() {
        identityGeneration &+= 1
        error = nil
    }

    private nonisolated static func displayName(_ profile: UserProfile) -> String {
        "\(profile.firstName) \(profile.lastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
