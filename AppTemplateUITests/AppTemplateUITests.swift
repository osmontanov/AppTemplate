import XCTest

// Journey ownership lives under AppTemplateUITests/Journeys. Keeping the target's
// original file avoids creating a second test owner or private launch path.
nonisolated
final class AppTemplateUITests: XCTestCase {}
