import XCTest
@testable import AdrenalineCore

final class DiskTypeDetectorTests: XCTestCase {
    func testInitWithExplicitValue() {
        let withHDD = DiskTypeDetector(hasNonSSDDrive: true)
        XCTAssertTrue(withHDD.hasNonSSDDrive)

        let allSSD = DiskTypeDetector(hasNonSSDDrive: false)
        XCTAssertFalse(allSSD.hasNonSSDDrive)
    }
}
