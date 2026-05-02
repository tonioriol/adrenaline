import XCTest
@testable import InsomniaCore

final class LidStateMonitorTests: XCTestCase {
    func testClamshellArgumentWithoutStateBitMeansOpen() {
        XCTAssertEqual(
            LidStateMonitor.lidState(fromClamshellMessageArgument: 0),
            .open
        )
    }

    func testClamshellArgumentWithStateBitMeansClosed() {
        XCTAssertEqual(
            LidStateMonitor.lidState(fromClamshellMessageArgument: LidStateMonitor.clamshellStateBit),
            .closed
        )
    }

    func testClamshellArgumentIgnoresSleepBitForOpenClosedMapping() {
        let sleepBitOnly = UInt(1 << 1)
        let closedWithSleepBit = LidStateMonitor.clamshellStateBit | sleepBitOnly

        XCTAssertEqual(
            LidStateMonitor.lidState(fromClamshellMessageArgument: sleepBitOnly),
            .open
        )
        XCTAssertEqual(
            LidStateMonitor.lidState(fromClamshellMessageArgument: closedWithSleepBit),
            .closed
        )
    }

    func testClamshellStateChangeMessageMatchesIOKitMacroFormula() {
        let sysIOKit = UInt32(0x38 << 26)
        let subIOKitPowerManagement = UInt32(13 << 14)
        let clamshellMessage = UInt32(0x100)

        XCTAssertEqual(
            LidStateMonitor.clamshellStateChangeMessage,
            sysIOKit | subIOKitPowerManagement | clamshellMessage
        )
    }
}
