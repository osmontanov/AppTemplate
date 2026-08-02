nonisolated
enum AboutRoute: NavigationRoute {
    case platform(AppPlatform)

    private enum CodingKeys: String, CodingKey {
        case platform
    }

    private enum PlatformCodingKeys: String, CodingKey {
        case platform
        case synthesizedPlatform = "_0"
        case legacyName = "name"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let payload = try container.nestedContainer(
            keyedBy: PlatformCodingKeys.self,
            forKey: .platform
        )

        if let platform = try payload.decodeIfPresent(
            AppPlatform.self,
            forKey: .platform
        ) {
            self = .platform(platform)
            return
        }

        if let platform = try payload.decodeIfPresent(
            AppPlatform.self,
            forKey: .synthesizedPlatform
        ) {
            self = .platform(platform)
            return
        }

        if let legacyName = try payload.decodeIfPresent(
            String.self,
            forKey: .legacyName
        ) {
            guard let platform = Self.platform(forLegacyName: legacyName) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .legacyName,
                    in: payload,
                    debugDescription: "Unsupported legacy platform name."
                )
            }
            self = .platform(platform)
            return
        }

        throw DecodingError.dataCorruptedError(
            forKey: .platform,
            in: payload,
            debugDescription: "Missing platform route payload."
        )
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case let .platform(platform):
            var container = encoder.container(keyedBy: CodingKeys.self)
            var payload = container.nestedContainer(
                keyedBy: PlatformCodingKeys.self,
                forKey: .platform
            )
            try payload.encode(platform, forKey: .platform)
        }
    }

    private static func platform(
        forLegacyName name: String
    ) -> AppPlatform? {
        switch name {
        case "iOS 26":
            .iOS
        case "iPadOS 26":
            .iPadOS
        case "macOS 26":
            .macOS
        default:
            nil
        }
    }
}
