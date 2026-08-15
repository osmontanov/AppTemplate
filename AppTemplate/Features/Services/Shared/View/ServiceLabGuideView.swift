import SwiftUI

struct ServiceLabGuideView<TryItContent: View, AdvancedContent: View>: View {
    let guide: ServiceLabGuide
    let result: ServiceLabResult
    let resetDemoData: (() -> Void)?
    private let tryItContent: TryItContent
    private let advancedContent: AdvancedContent
    @AccessibilityFocusState private var resultIsFocused: Bool

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
                            Button(StoreServicesText.resource(.resetDemoData), action: resetDemoData)
                                .frame(minHeight: 44)
                                .accessibilityIdentifier(AppAccessibilityIdentifier.action(.resetService))
                        } else {
                            Text(StoreServicesText.resource("No demo data has been created."))
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
        .controlSize(.large)
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.serviceLab))
        }
        .task {
            resultIsFocused = result != .idle && result != .running
            guard result != .idle else { return }
            AccessibilityNotification.Announcement(announcement(for: result)).post()
        }
        .onChange(of: result) { _, newValue in
            resultIsFocused = newValue != .idle && newValue != .running
            guard newValue != .idle else { return }
            AccessibilityNotification.Announcement(announcement(for: newValue)).post()
        }
    }

    @ViewBuilder
    private var resultPresentation: some View {
        switch result {
        case .idle:
            Label(StoreServicesText.resource("Not run"), systemImage: "circle.dashed")
                .foregroundStyle(.secondary)
        case .running:
            HStack {
                ProgressView()
                Text(StoreServicesText.resource("Running"))
            }
            .accessibilityIdentifier(AppAccessibilityIdentifier.result(.loading))
        case let .success(message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel(StoreServicesText.resource("Operation succeeded"))
                .accessibilityFocused($resultIsFocused)
                .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualSuccess))
        case let .failure(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel(StoreServicesText.resource("Operation failed"))
                .accessibilityFocused($resultIsFocused)
                .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualFailure))
        }
    }

    private func announcement(for result: ServiceLabResult) -> String {
        switch result {
        case .idle: StoreServicesText.string("Ready")
        case .running: StoreServicesText.string("Operation running")
        case .success: StoreServicesText.string("Operation succeeded")
        case .failure: StoreServicesText.string("Operation failed")
        }
    }
}
