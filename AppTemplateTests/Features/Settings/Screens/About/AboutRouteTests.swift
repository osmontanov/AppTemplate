import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct AboutRouteTests {
    @Test
    func stablePlatformRouteRoundTripsWithNamedWirePayload() throws {
        let route = AboutRoute.platform(.iPadOS)

        let data = try JSONEncoder().encode(route)
        let decoded = try JSONDecoder().decode(AboutRoute.self, from: data)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let payload = try #require(
            object["platform"] as? [String: String]
        )

        #expect(decoded == route)
        #expect(payload == ["platform": "iPadOS"])
    }

    @Test(arguments: [
        ("iOS 26", AppPlatform.iOS),
        ("iPadOS 26", AppPlatform.iPadOS),
        ("macOS 26", AppPlatform.macOS)
    ])
    func recognizedLegacyPlatformLabelDecodesToStablePlatform(
        legacyLabel: String,
        expectedPlatform: AppPlatform
    ) throws {
        let route = try decodeLegacyRoute(label: legacyLabel)

        #expect(route == .platform(expectedPlatform))
    }

    @Test
    func unknownLegacyPlatformLabelIsRejected() {
        #expect(throws: DecodingError.self) {
            try decodeLegacyRoute(label: "visionOS 26")
        }
    }

    @Test
    func synthesizedStablePayloadRemainsDecodable() throws {
        let data = Data(
            #"{"platform":{"_0":"iPadOS"}}"#.utf8
        )

        #expect(
            try JSONDecoder().decode(AboutRoute.self, from: data)
                == .platform(.iPadOS)
        )
    }

    @Test
    func legacyRouteBuildsDestinationModelWithStablePlatform() throws {
        let route = try decodeLegacyRoute(label: "iPadOS 26")

        switch route {
        case let .platform(platform):
            let viewModel = PlatformDetailsViewModel(platform: platform)

            #expect(viewModel.platform == .iPadOS)
        }
    }

    private func decodeLegacyRoute(label: String) throws -> AboutRoute {
        let data = try JSONSerialization.data(
            withJSONObject: [
                "platform": [
                    "name": label
                ]
            ]
        )
        return try JSONDecoder().decode(AboutRoute.self, from: data)
    }
}
