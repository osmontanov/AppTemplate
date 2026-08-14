import Foundation

nonisolated enum UITestConfigurationError: Error, Equatable, Sendable {
    case missingScenario
    case duplicateOption(String)
    case unknownOption(String)
    case unknownScenario(String)
    case malformedValue(option: String)
}

nonisolated enum AppLaunchConfiguration: Equatable, Sendable {
    case live
    case uiTesting(UITestScenario)
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
        let optionIndices = values.indices.filter { values[$0] == scenarioOption }
        if optionIndices.count > 1 {
            self = .invalidUITesting(.duplicateOption(scenarioOption))
            return
        }
        if let unknown = values.first(where: {
            $0.hasPrefix("--ui-") && $0 != marker && $0 != scenarioOption
        }) {
            self = .invalidUITesting(.unknownOption(unknown))
            return
        }
        guard markers == 1, let optionIndex = optionIndices.first else {
            self = .invalidUITesting(.missingScenario)
            return
        }
        let valueIndex = values.index(after: optionIndex)
        guard valueIndex < values.endIndex,
              !values[valueIndex].hasPrefix("-"),
              !values[valueIndex].trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty
        else {
            self = .invalidUITesting(.malformedValue(option: scenarioOption))
            return
        }
        do {
            self = .uiTesting(
                try UITestScenario.named(values[valueIndex]).preparedForLaunch()
            )
        } catch let error as UITestConfigurationError {
            self = .invalidUITesting(error)
        } catch {
            self = .invalidUITesting(.malformedValue(option: scenarioOption))
        }
    }
}
