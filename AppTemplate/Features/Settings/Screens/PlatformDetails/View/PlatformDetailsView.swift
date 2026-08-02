import SwiftUI

struct PlatformDetailsView: View {
    @State private var viewModel: PlatformDetailsViewModel

    init(platform: AppPlatform) {
        _viewModel = State(
            initialValue: PlatformDetailsViewModel(platform: platform)
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "laptopcomputer")
                .font(.largeTitle)
            Text(viewModel.platform.localizedTitle)
                .font(.title)
            Text("Platform Details")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Platform Details")
    }
}

extension AppPlatform {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .iOS:
            "iOS 26"
        case .iPadOS:
            "iPadOS 26"
        case .macOS:
            "macOS 26"
        }
    }
}
