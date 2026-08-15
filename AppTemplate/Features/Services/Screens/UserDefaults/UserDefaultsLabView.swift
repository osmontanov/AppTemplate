import SwiftUI

struct UserDefaultsLabView: View {
    private let guide: ServiceLabGuide
    @State private var model: UserDefaultsLabViewModel
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    init(guide: ServiceLabGuide, service: any IUserDefaultsService) {
        self.guide = guide
        _model = State(initialValue: UserDefaultsLabViewModel(service: service))
    }

    var body: some View {
        ServiceLabGuideView(
            guide: guide,
            result: model.actualResult,
            resetDemoData: model.resetDemoData
        ) {
            operationRow(.bool)
            operationRow(.string)
        } advanced: {
            ForEach(UserDefaultsLabKind.allCases.filter { $0 != .bool && $0 != .string }, id: \.self) {
                operationRow($0)
            }
            Text(StoreServicesText.resource("Each key is typed and scoped to the dedicated Services lab namespace."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(StoreServicesText.resource("UserDefaults"))
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("screen.services.user-defaults")
        }
    }

    @ViewBuilder
    private func operationRow(_ kind: UserDefaultsLabKind) -> some View {
        VStack(alignment: .leading) {
            Text(kind.title).font(.headline)
            HStack {
                if kind == .bool {
                    Button(StoreServicesText.resource("Save")) { perform { try model.save(kind) } }
                        .accessibilityIdentifier(AppAccessibilityIdentifier.action(.tryService))
                } else {
                    Button(StoreServicesText.resource("Save")) { perform { try model.save(kind) } }
                }
                Button(StoreServicesText.resource("Read")) {
                    perform { try model.read(kind, locale: locale, timeZone: timeZone) }
                }
                Button(StoreServicesText.resource("Remove")) { model.remove(kind) }
            }
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { /* The model publishes a bounded failure. */ }
    }
}
