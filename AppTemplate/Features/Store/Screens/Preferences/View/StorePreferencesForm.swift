import SwiftUI

struct StorePreferencesForm: View {
    let repository: any IStorePreferencesRepository
    @State private var preferences = StorePreferences.defaults
    @State private var errorMessage: String?

    var body: some View {
        Group {
            Picker("Layout", selection: Binding(
                get: { preferences.layout },
                set: { value in Task { await setLayout(value) } }
            )) {
                Text("Grid").tag(StoreCatalogLayout.grid)
                Text("List").tag(StoreCatalogLayout.list)
            }
            Picker("Sort", selection: Binding(
                get: { preferences.sort },
                set: { value in Task { await setSort(value) } }
            )) {
                ForEach(StoreCatalogSort.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Remote page size", selection: Binding(
                get: { preferences.preferredRemotePageSize },
                set: { value in Task { await setPageSize(value) } }
            )) {
                ForEach(CatalogViewModel.pageSizeChoices, id: \.self) { Text("\($0)").tag($0) }
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
        catch { errorMessage = "Preferences could not be saved." }
    }
    private func setSort(_ value: StoreCatalogSort) async {
        do { try await repository.setSort(value) }
        catch { errorMessage = "Preferences could not be saved." }
    }
    private func setPageSize(_ value: Int) async {
        do { try await repository.setPreferredRemotePageSize(value) }
        catch { errorMessage = "Preferences could not be saved." }
    }
}
