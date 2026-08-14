import SwiftUI

struct ServicesAppInfoView: View {
    private let guide: ServiceLabGuide
    private let model: ServicesAppInfoViewModel

    init(
        guide: ServiceLabGuide,
        appInfo: any IAppInfoService,
        platformName: String
    ) {
        self.guide = guide
        model = ServicesAppInfoViewModel(
            appInfo: appInfo,
            platformName: platformName
        )
    }

    var body: some View {
        ServiceLabGuideView(
            guide: guide,
            result: .success("Read shared application metadata.")
        ) {
            LabeledContent("Display Name", value: model.displayName)
            LabeledContent("Version", value: model.version)
            LabeledContent("Platform", value: model.platformName)
        } advanced: {
            Text("The model receives application metadata and a view-derived platform label. It does not inspect Bundle or platform globals.")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("App Info")
        .accessibilityIdentifier("screen.services.app-info")
    }
}
