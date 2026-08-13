nonisolated protocol IStorePreferencesRepository: Sendable {
    func current() async -> StorePreferences
    func updates() async -> AsyncStream<StorePreferences>
    func setLayout(_ layout: StoreCatalogLayout) async throws
    func setSort(_ sort: StoreCatalogSort) async throws
    func setPreferredRemotePageSize(_ size: Int) async throws
}
