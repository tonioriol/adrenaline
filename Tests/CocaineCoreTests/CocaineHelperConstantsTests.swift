import XCTest
@testable import CocaineCore

final class CocaineHelperConstantsTests: XCTestCase {
    func testAppCodeSigningRequirementIncludesAppIdentifierAndTeamIdentifier() {
        XCTAssertTrue(CocaineHelperConstants.appCodeSigningRequirement.contains("com.tr0n.Cocaine"))
        XCTAssertTrue(CocaineHelperConstants.appCodeSigningRequirement.contains("A79T83GM42"))
    }

    func testHelperCodeSigningRequirementIncludesHelperIdentifierAndTeamIdentifier() {
        XCTAssertTrue(CocaineHelperConstants.helperCodeSigningRequirement.contains("com.tr0n.Cocaine.Helper"))
        XCTAssertTrue(CocaineHelperConstants.helperCodeSigningRequirement.contains("A79T83GM42"))
    }
}
