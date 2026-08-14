import Foundation
import SwiftUI

nonisolated enum UITestContentSize: String, Sendable {
    case standard
    case accessibilityExtraExtraExtraLarge

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .standard: .large
        case .accessibilityExtraExtraExtraLarge: .accessibility5
        }
    }
}

nonisolated enum UITestLayoutDirection: String, Sendable {
    case leftToRight
    case rightToLeft

    var swiftUILayoutDirection: LayoutDirection {
        switch self {
        case .leftToRight: .leftToRight
        case .rightToLeft: .rightToLeft
        }
    }
}

nonisolated enum UITestLocale: String, Sendable {
    case system
    case arabic = "ar_SA"

    var localeIdentifier: String? {
        switch self {
        case .system: nil
        case .arabic: rawValue
        }
    }
}

nonisolated enum UITestLocalizationVariant: String, Sendable {
    case standard
    case doubled
}

nonisolated struct UITestPresentationOverrides: Equatable, Sendable {
    let contentSize: UITestContentSize
    let layoutDirection: UITestLayoutDirection
    let locale: UITestLocale
    let reduceMotion: Bool

    static let standard = Self(
        contentSize: .standard,
        layoutDirection: .leftToRight,
        locale: .system,
        reduceMotion: false
    )
    static let largestText = Self(
        contentSize: .accessibilityExtraExtraExtraLarge,
        layoutDirection: .leftToRight,
        locale: .system,
        reduceMotion: false
    )
    static let arabicRTL = Self(
        contentSize: .standard,
        layoutDirection: .rightToLeft,
        locale: .arabic,
        reduceMotion: false
    )
}

nonisolated enum UITestConfigurationError: Error, Equatable, Sendable {
    case missingScenario
    case duplicateOption(String)
    case unknownOption(String)
    case unknownScenario(String)
    case malformedValue(option: String)
}

nonisolated enum AppLaunchConfiguration: Equatable, Sendable {
    case live
    case uiTesting(UITestScenario, UITestPresentationOverrides)
    case invalidUITesting(UITestConfigurationError)

    var sceneNavigationPersistencePolicy: AppSceneNavigationPersistencePolicy {
        switch self {
        case .live: .restored
        case .uiTesting, .invalidUITesting: .ephemeral
        }
    }

    init(arguments: [String]) {
        let marker = "--ui-testing"
        let scenarioOption = "--ui-test-scenario"
        let contentSizeOption = "--ui-test-content-size"
        let layoutDirectionOption = "--ui-test-layout-direction"
        let localeOption = "--ui-test-locale"
        let reduceMotionOption = "--ui-test-reduce-motion"
        let valueOptions = [
            scenarioOption, contentSizeOption, layoutDirectionOption, localeOption
        ]
        let recognizedOptions = Set(valueOptions + [marker, reduceMotionOption])
        var values = Array(arguments.dropFirst())

        #if os(macOS)
        if values.starts(with: ["-ApplePersistenceIgnoreState", "YES"]) {
            values.removeFirst(2)
        }
        if values.contains("-ApplePersistenceIgnoreState") {
            self = .invalidUITesting(
                .unknownOption("-ApplePersistenceIgnoreState")
            )
            return
        }
        #endif

        let containsUIIntent = values.contains(marker)
            || values.contains(scenarioOption)
            || values.contains(where: { $0.hasPrefix("--ui-") })
        guard containsUIIntent else {
            self = .live
            return
        }

        let markers = values.filter { $0 == marker }.count
        if markers > 1 {
            self = .invalidUITesting(.duplicateOption(marker))
            return
        }
        if let unknown = values.first(where: {
            $0.hasPrefix("--ui-") && !recognizedOptions.contains($0)
        }) {
            self = .invalidUITesting(.unknownOption(unknown))
            return
        }
        for option in valueOptions {
            if values.filter({ $0 == option }).count > 1 {
                self = .invalidUITesting(.duplicateOption(option))
                return
            }
        }
        if values.filter({ $0 == reduceMotionOption }).count > 1 {
            self = .invalidUITesting(.duplicateOption(reduceMotionOption))
            return
        }

        let scenarioIndices = values.indices.filter { values[$0] == scenarioOption }
        guard markers == 1, let optionIndex = scenarioIndices.first else {
            self = .invalidUITesting(.missingScenario)
            return
        }

        do {
            let scenarioID = try Self.value(
                for: scenarioOption,
                at: optionIndex,
                in: values
            )
            let contentSize = try Self.parsedValue(
                option: contentSizeOption,
                in: values,
                default: UITestContentSize.standard
            )
            let layoutDirection = try Self.parsedValue(
                option: layoutDirectionOption,
                in: values,
                default: UITestLayoutDirection.leftToRight
            )
            let locale = try Self.parsedValue(
                option: localeOption,
                in: values,
                default: UITestLocale.system
            )
            self = .uiTesting(
                try UITestScenario.named(scenarioID).preparedForLaunch(),
                UITestPresentationOverrides(
                    contentSize: contentSize,
                    layoutDirection: layoutDirection,
                    locale: locale,
                    reduceMotion: values.contains(reduceMotionOption)
                )
            )
        } catch let error as UITestConfigurationError {
            self = .invalidUITesting(error)
        } catch {
            self = .invalidUITesting(.malformedValue(option: scenarioOption))
        }
    }

    private static func value(
        for option: String,
        at optionIndex: Int,
        in values: [String]
    ) throws -> String {
        let valueIndex = values.index(after: optionIndex)
        guard valueIndex < values.endIndex,
              !values[valueIndex].hasPrefix("-"),
              !values[valueIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw UITestConfigurationError.malformedValue(option: option)
        }
        return values[valueIndex]
    }

    private static func parsedValue<Value: RawRepresentable>(
        option: String,
        in values: [String],
        default defaultValue: Value
    ) throws -> Value where Value.RawValue == String {
        guard let optionIndex = values.firstIndex(of: option) else {
            return defaultValue
        }
        let rawValue = try value(for: option, at: optionIndex, in: values)
        guard let value = Value(rawValue: rawValue) else {
            throw UITestConfigurationError.malformedValue(option: option)
        }
        return value
    }
}
