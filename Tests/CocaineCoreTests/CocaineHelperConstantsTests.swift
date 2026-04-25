import XCTest
@testable import CocaineCore

final class CocaineHelperConstantsTests: XCTestCase {
    private let expectedAppRequirement = "anchor apple generic and identifier \"com.tr0n.Cocaine\" and certificate leaf[subject.CN] = \"Apple Development: tonioriol@me.com (A79T83GM42)\" and certificate 1[field.1.2.840.113635.100.6.2.1] exists"
    private let expectedHelperRequirement = "anchor apple generic and identifier \"com.tr0n.Cocaine.Helper\" and certificate leaf[subject.CN] = \"Apple Development: tonioriol@me.com (A79T83GM42)\" and certificate 1[field.1.2.840.113635.100.6.2.1] exists"

    func testAppBundlePrivilegedHelperRequirementMatchesHelperSigningRequirement() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let infoPlistURL = projectRoot.appendingPathComponent("Resources/Cocaine/Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let helperMap = try XCTUnwrap(plist["SMPrivilegedExecutables"] as? [String: String])

        XCTAssertEqual(
            helperMap[CocaineHelperConstants.helperBundleIdentifier],
            CocaineHelperConstants.helperCodeSigningRequirement
        )
    }

    func testAppCodeSigningRequirementMatchesLocalDesignatedRequirementShape() {
        XCTAssertEqual(
            CocaineHelperConstants.appCodeSigningRequirement,
            expectedAppRequirement
        )
    }

    func testHelperCodeSigningRequirementMatchesLocalDesignatedRequirementShape() {
        XCTAssertEqual(
            CocaineHelperConstants.helperCodeSigningRequirement,
            expectedHelperRequirement
        )
    }

    func testHelperAuthorizedClientsMatchesAppSigningRequirement() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let infoPlistURL = projectRoot.appendingPathComponent("Resources/CocaineHelper/Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let clients = try XCTUnwrap(plist["SMAuthorizedClients"] as? [String])

        XCTAssertEqual(clients.first, expectedAppRequirement)
    }
}
