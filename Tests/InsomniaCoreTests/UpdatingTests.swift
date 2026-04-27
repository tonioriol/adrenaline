import XCTest
@testable import InsomniaCore

final class UpdatingTests: XCTestCase {
    func testIdleStatusEquality() {
        let date = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(UpdaterStatus.idle(lastChecked: date), .idle(lastChecked: date))
        XCTAssertNotEqual(UpdaterStatus.idle(lastChecked: nil), .idle(lastChecked: date))
    }

    func testCheckingIsItsOwnState() {
        XCTAssertEqual(UpdaterStatus.checking, .checking)
        XCTAssertNotEqual(UpdaterStatus.checking, .upToDate)
    }

    func testUpdateAvailableCarriesVersion() {
        XCTAssertEqual(
            UpdaterStatus.updateAvailable(version: "0.3.0"),
            .updateAvailable(version: "0.3.0")
        )
        XCTAssertNotEqual(
            UpdaterStatus.updateAvailable(version: "0.3.0"),
            .updateAvailable(version: "0.4.0")
        )
    }

    func testErrorCarriesMessage() {
        XCTAssertEqual(UpdaterStatus.error("offline"), .error("offline"))
        XCTAssertNotEqual(UpdaterStatus.error("offline"), .error("server"))
    }
}
