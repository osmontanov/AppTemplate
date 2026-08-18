import SwiftUI

struct RemoteImage: View {
    private let url: URL
    private let images: ImageService

    @State private var loaded: AppImage?

    init(url: URL, images: ImageService) {
        self.url = url
        self.images = images
    }

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .task(id: url) {
            loaded = nil
            do {
                let image = try await images.image(for: url)
                // A load resumed after SwiftUI moved this view to another URL
                // must not paint the old image over the new one.
                guard !Task.isCancelled else { return }
                loaded = image
            } catch ImageServiceError.cancelled {
                return
            } catch {
                loaded = nil
            }
        }
    }

    private var image: Image? {
        guard let loaded else { return nil }
        #if os(macOS)
        return Image(nsImage: loaded)
        #else
        return Image(uiImage: loaded)
        #endif
    }
}
