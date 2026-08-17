import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct RemoteProductImage: View {
    let url: URL
    let imageLoader: any IImageLoader
    let policy: ImageLoadPolicy

    @State private var loadedImage: LoadedImage?

    init(
        url: URL,
        imageLoader: any IImageLoader,
        policy: ImageLoadPolicy = .product
    ) {
        self.url = url
        self.imageLoader = imageLoader
        self.policy = policy
    }

    var body: some View {
        Group {
            if let image = platformImage {
                image
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .task(id: url) {
            loadedImage = nil
            do {
                let image = try await imageLoader.load(url, policy: policy)
                try Task.checkCancellation()
                loadedImage = image
            } catch is CancellationError {
                return
            } catch {
                loadedImage = nil
            }
        }
    }

    private var platformImage: Image? {
        guard let loadedImage else { return nil }
        #if os(macOS)
        guard let image = NSImage(data: loadedImage.data) else { return nil }
        return Image(nsImage: image)
        #elseif os(iOS)
        guard let image = UIImage(data: loadedImage.data) else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }
}
