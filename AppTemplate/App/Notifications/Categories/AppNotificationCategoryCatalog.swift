import Foundation

nonisolated
final class AppNotificationCategoryCatalog: IAppNotificationCategoryCatalog {
    private let service: any ILocalNotificationService
    private let storeCategory: LocalNotificationCategory
    private let gate: AsyncOperationGate
    private let state: CategoryCatalogState

    init(
        service: any ILocalNotificationService,
        storeCategory: LocalNotificationCategory,
        gate: AsyncOperationGate
    ) {
        self.service = service
        self.storeCategory = storeCategory
        self.gate = gate
        state = CategoryCatalogState(storeCategory: storeCategory)
    }

    func categories() async -> [LocalNotificationCategory] {
        await state.categories()
    }

    func bootstrapIfNeeded() async throws {
        try await gate.withExclusiveAccess { [service, state] in
            guard let candidate = await state.bootstrapCandidateIfNeeded() else {
                return
            }
            try await service.setCategories(candidate.union)
            await state.commit(candidate)
        }
    }

    func replaceLabCategories(
        _ categories: [LocalNotificationCategory]
    ) async throws {
        try await gate.withExclusiveAccess { [service, state, categories] in
            let candidate = try await state.candidate(
                replacingLabWith: categories
            )
            try await service.setCategories(candidate.union)
            await state.commit(candidate)
        }
    }

    func resetLabCategories() async throws {
        try await replaceLabCategories([])
    }
}

private struct CategoryCatalogCandidate: Sendable {
    let union: [LocalNotificationCategory]
    let normalizedLabCategories: [LocalNotificationCategory]
}

private actor CategoryCatalogState {
    private let storeCategory: LocalNotificationCategory
    private var committedLabCategories: [LocalNotificationCategory] = []
    private var isBootstrapped = false

    init(storeCategory: LocalNotificationCategory) {
        self.storeCategory = storeCategory
    }

    func bootstrapCandidateIfNeeded() -> CategoryCatalogCandidate? {
        guard !isBootstrapped else { return nil }
        return CategoryCatalogCandidate(
            union: [storeCategory] + committedLabCategories,
            normalizedLabCategories: committedLabCategories
        )
    }

    func candidate(
        replacingLabWith categories: [LocalNotificationCategory]
    ) throws -> CategoryCatalogCandidate {
        var seenIDs: Set<LocalNotificationCategoryID> = []
        for category in categories {
            guard category.id != storeCategory.id,
                  seenIDs.insert(category.id).inserted else {
                throw LocalNotificationServiceError.invalidCategory(
                    .duplicateCategoryID
                )
            }
        }
        let normalized = categories.sorted { lhs, rhs in
            lhs.id.value < rhs.id.value
        }
        return CategoryCatalogCandidate(
            union: [storeCategory] + normalized,
            normalizedLabCategories: normalized
        )
    }

    func commit(_ candidate: CategoryCatalogCandidate) {
        committedLabCategories = candidate.normalizedLabCategories
        isBootstrapped = true
    }

    func categories() -> [LocalNotificationCategory] {
        [storeCategory] + committedLabCategories
    }
}
