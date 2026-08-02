import SwiftUI

struct AdaptiveContentContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
