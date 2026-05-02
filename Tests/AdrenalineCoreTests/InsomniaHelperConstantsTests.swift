import XCTest
@testable import AdrenalineCore

final class AdrenalineHelperConstantsTests: XCTestCase {
    private let expectedAppRequirement = "anchor apple generic and identifier \"com.tonioriol.adrenaline\" and certificate leaf[subject.OU] = \"B65K228Z97\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
    private let expectedHelperRequirement = "anchor apple generic and identifier \"com.tonioriol.adrenaline.helper\" and certificate leaf[subject.OU] = \"B65K228Z97\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"

    func testAppBundlePrivilegedHelperRequirementMatchesHelperSigningRequirement() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let infoPlistURL = projectRoot.appendingPathComponent("Resources/Adrenaline/Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let helperMap = try XCTUnwrap(plist["SMPrivilegedExecutables"] as? [String: String])

        XCTAssertEqual(
            helperMap[AdrenalineHelperConstants.helperBundleIdentifier],
            AdrenalineHelperConstants.helperCodeSigningRequirement
        )
    }

    func testAppCodeSigningRequirementMatchesLocalDesignatedRequirementShape() {
        XCTAssertEqual(
            AdrenalineHelperConstants.appCodeSigningRequirement,
            expectedAppRequirement
        )
    }

    func testHelperCodeSigningRequirementMatchesLocalDesignatedRequirementShape() {
        XCTAssertEqual(
            AdrenalineHelperConstants.helperCodeSigningRequirement,
            expectedHelperRequirement
        )
    }

    func testHelperAuthorizedClientsMatchesAppSigningRequirement() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let infoPlistURL = projectRoot.appendingPathComponent("Resources/AdrenalineHelper/Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let clients = try XCTUnwrap(plist["SMAuthorizedClients"] as? [String])

        XCTAssertEqual(clients.first, expectedAppRequirement)
    }
}
