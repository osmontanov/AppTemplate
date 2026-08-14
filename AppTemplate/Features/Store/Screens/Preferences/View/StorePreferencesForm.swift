import SwiftUI

struct StorePreferencesForm: View {
    let repository: any IStorePreferencesRepository
    @State private var preferences = StorePreferences.defaults
    @State private var errorMessage: String?

    var body: some View {
        Group {
            Picker(StoreServicesText.resource("Layout"), selection: Binding(
                get: { preferences.layout },
                set: { value in Task { await setLayout(value) } }
            )) {
                Text(StoreServicesText.resource("Grid")).tag(StoreCatalogLayout.grid)
                Text(StoreServicesText.resource("List")).tag(StoreCatalogLayout.list)
            }
            Picker(StoreServicesText.resource("Sort"), selection: Binding(
                get: { preferences.sort },
                set: { value in Task { await setSort(value) } }
            )) {
                ForEach(StoreCatalogSort.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker(StoreServicesText.resource("Remote page size"), selection: Binding(
                get: { preferences.preferredRemotePageSize },
                set: { value in Task { await setPageSize(value) } }
            )) {
                ForEach(CatalogViewModel.pageSizeChoices, id: \.self) { Text(StoreServicesText.resource("\($0)")).tag($0) }
            }
            if let errorMessage {
                Text(verbatim: errorMessage).foregroundStyle(.red)
            }
        }
        .task {
            preferences = await repository.current()
            for await update in await repository.updates() {
                guard !Task.isCancelled else { return }
                preferences = update
            }
        }
    }

    private func setLayout(_ value: StoreCatalogLayout) async {
        do { try await repository.setLayout(value) }
        catch { errorMessage = StoreServicesText.string("Preferences could not be saved.") }
    }
    private func setSort(_ value: StoreCatalogSort) async {
        do { try await repository.setSort(value) }
        catch { errorMessage = StoreServicesText.string("Preferences could not be saved.") }
    }
    private func setPageSize(_ value: Int) async {
        do { try await repository.setPreferredRemotePageSize(value) }
        catch { errorMessage = StoreServicesText.string("Preferences could not be saved.") }
    }
}
