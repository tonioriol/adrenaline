import XCTest
@testable import AdrenalineCore

final class InsomniaHelperConstantsTests: XCTestCase {
    private let expectedAppRequirement = "anchor apple generic and identifier \"com.tonioriol.insomnia\" and certificate leaf[subject.OU] = \"B65K228Z97\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
    private let expectedHelperRequirement = "anchor apple generic and identifier \"com.tonioriol.insomnia.helper\" and certificate leaf[subject.OU] = \"B65K228Z97\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"

    func testAppBundlePrivilegedHelperRequirementMatchesHelperSigningRequirement() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let infoPlistURL = projectRoot.appendingPathComponent("Resources/Insomnia/Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let helperMap = try XCTUnwrap(plist["SMPrivilegedExecutables"] as? [String: String])

        XCTAssertEqual(
            helperMap[InsomniaHelperConstants.helperBundleIdentifier],
            InsomniaHelperConstants.helperCodeSigningRequirement
        )
    }

    func testAppCodeSigningRequirementMatchesLocalDesignatedRequirementShape() {
        XCTAssertEqual(
            InsomniaHelperConstants.appCodeSigningRequirement,
            expectedAppRequirement
        )
    }

    func testHelperCodeSigningRequirementMatchesLocalDesignatedRequirementShape() {
        XCTAssertEqual(
            InsomniaHelperConstants.helperCodeSigningRequirement,
            expectedHelperRequirement
        )
    }

    func testHelperAuthorizedClientsMatchesAppSigningRequirement() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let infoPlistURL = projectRoot.appendingPathComponent("Resources/InsomniaHelper/Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let clients = try XCTUnwrap(plist["SMAuthorizedClients"] as? [String])

        XCTAssertEqual(clients.first, expectedAppRequirement)
    }
}
