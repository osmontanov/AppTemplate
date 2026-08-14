import SwiftUI

struct ServiceLabGuideView<TryItContent: View, AdvancedContent: View>: View {
    let guide: ServiceLabGuide
    let result: ServiceLabResult
    let resetDemoData: (() -> Void)?
    private let tryItContent: TryItContent
    private let advancedContent: AdvancedContent

    init(
        guide: ServiceLabGuide,
        result: ServiceLabResult,
        resetDemoData: (() -> Void)? = nil,
        @ViewBuilder tryIt: () -> TryItContent,
        @ViewBuilder advanced: () -> AdvancedContent
    ) {
        self.guide = guide
        self.result = result
        self.resetDemoData = resetDemoData
        tryItContent = tryIt()
        advancedContent = advanced()
    }

    var body: some View {
        Form {
            ForEach(ServiceLabGuideSection.allCases) { section in
                switch section {
                case .why:
                    Section(section.title) {
                        Text(guide.why)
                    }
                case .preset:
                    Section(section.title) {
                        Text(guide.preset)
                    }
                case .tryIt:
                    Section(section.title) {
                        tryItContent
                    }
                case .expected:
                    Section(section.title) {
                        Text(guide.expected)
                    }
                case .actual:
                    Section(section.title) {
                        resultPresentation
                    }
                case .resetDemoData:
                    Section(section.title) {
                        if let resetDemoData {
                            Button("Reset Demo Data", action: resetDemoData)
                        } else {
                            Text("No demo data has been created.")
                                .foregroundStyle(.secondary)
                        }
                    }
                case .advanced:
                    Section(section.title) {
                        advancedContent
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var resultPresentation: some View {
        switch result {
        case .idle:
            Label("Not run", systemImage: "circle.dashed")
                .foregroundStyle(.secondary)
        case .running:
            HStack {
                ProgressView()
                Text("Running")
            }
        case let .success(message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case let .failure(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}
