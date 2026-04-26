import XCTest
@testable import CocaineCore

final class PreferenceMenuRowsTests: XCTestCase {
    func testRowsExposeLockScreenOnLidCloseAsLidCloseChildPreference() {
        let snapshot = PreferencesSnapshot(
            preventDisplaySleep: false,
            preventLidCloseSleep: true,
            lockScreenOnLidClose: false,
            playLidEventSounds: false
        )

        let rows = PreferenceMenuRows.rows(for: snapshot)

        XCTAssertEqual(rows.map(\.id), [
            .preventDisplaySleep,
            .preventLidCloseSleep,
            .lockScreenOnLidClose,
            .playLidEventSounds,
        ])

        let row = rows.first { $0.id == .lockScreenOnLidClose }
        XCTAssertEqual(row?.title, "Lock screen on lid close")
        XCTAssertEqual(row?.isOn, false)
        XCTAssertEqual(row?.isEnabled, true)
        XCTAssertEqual(row?.isChild, true)
    }

    func testLockScreenOnLidCloseRowIsDisabledWhenLidClosePreventionIsOff() {
        let snapshot = PreferencesSnapshot(
            preventDisplaySleep: true,
            preventLidCloseSleep: false,
            lockScreenOnLidClose: true,
            playLidEventSounds: true
        )

        let row = PreferenceMenuRows.rows(for: snapshot)
            .first { $0.id == .lockScreenOnLidClose }

        XCTAssertEqual(row?.isOn, true)
        XCTAssertEqual(row?.isEnabled, false)
        XCTAssertEqual(row?.isChild, true)
    }
}
