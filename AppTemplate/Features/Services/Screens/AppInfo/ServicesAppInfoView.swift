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
            result: .success(StoreServicesText.string("Read shared application metadata."))
        ) {
            LabeledContent(StoreServicesText.resource("Display Name"), value: model.displayName)
            LabeledContent(StoreServicesText.resource("Version"), value: model.version)
            LabeledContent(StoreServicesText.resource("Platform"), value: model.platformName)
        } advanced: {
            Text(StoreServicesText.resource("The model receives application metadata and a view-derived platform label. It does not inspect Bundle or platform globals."))
                .foregroundStyle(.secondary)
        }
        .navigationTitle(StoreServicesText.resource("App Info"))
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("screen.services.app-info")
        }
    }
}
