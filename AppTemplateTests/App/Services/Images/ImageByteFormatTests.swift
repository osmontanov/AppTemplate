import Foundation
import Testing
@testable import AppTemplate

struct ImageByteFormatTests {
    @Test
    func parsesDeclaredContentTypeIgnoringParametersAndCase() {
        #expect(ImageByteFormat(contentType: "image/png") == .png)
        #expect(ImageByteFormat(contentType: "IMAGE/PNG; charset=binary") == .png)
        #expect(ImageByteFormat(contentType: "  image/jpeg  ") == .jpeg)
        #expect(ImageByteFormat(contentType: "image/svg+xml") == nil)
        #expect(ImageByteFormat(contentType: "text/html") == nil)
        #expect(ImageByteFormat(contentType: nil) == nil)
    }

    @Test
    func detectsOnlyTheFourAllowlistedSignatures() {
        #expect(ImageByteFormat(signatureOf: ImageFixtures.png) == .png)
        #expect(ImageByteFormat(signatureOf: ImageFixtures.jpegHeader) == .jpeg)
        #expect(ImageByteFormat(signatureOf: ImageFixtures.gifHeader) == .gif)
        #expect(ImageByteFormat(signatureOf: ImageFixtures.webpHeader) == .webp)
        #expect(ImageByteFormat(signatureOf: Data("<svg xmlns=".utf8)) == nil)
        #expect(ImageByteFormat(signatureOf: Data()) == nil)
    }

    @Test
    func riffContainerThatIsNotWebPIsNotAnImage() {
        let riffWave = Data("RIFF".utf8) + Data([0, 0, 0, 0]) + Data("WAVE".utf8)
        #expect(ImageByteFormat(signatureOf: riffWave) == nil)
    }
}
