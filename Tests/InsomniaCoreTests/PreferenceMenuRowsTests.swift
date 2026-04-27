import XCTest
@testable import InsomniaCore

final class PreferenceMenuRowsTests: XCTestCase {
    func testRowsExposePlayLidEventSoundsAsLidCloseChildPreference() {
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
            .playLidEventSounds,
        ])

        let row = rows.first { $0.id == .playLidEventSounds }
        XCTAssertEqual(row?.title, "Play lid event sounds")
        XCTAssertEqual(row?.isOn, false)
        XCTAssertEqual(row?.isEnabled, true)
        XCTAssertEqual(row?.isChild, true)
    }

    func testPlayLidEventSoundsRowIsDisabledWhenLidClosePreventionIsOff() {
        let snapshot = PreferencesSnapshot(
            preventDisplaySleep: true,
            preventLidCloseSleep: false,
            lockScreenOnLidClose: true,
            playLidEventSounds: true
        )

        let row = PreferenceMenuRows.rows(for: snapshot)
            .first { $0.id == .playLidEventSounds }

        XCTAssertEqual(row?.isOn, true)
        XCTAssertEqual(row?.isEnabled, false)
        XCTAssertEqual(row?.isChild, true)
    }
}
