import XCTest
@testable import AdrenalineCore

final class PreferenceMenuRowsTests: XCTestCase {
    func testRowsExposePlayLidEventSoundsAsLidCloseChildPreference() {
        let snapshot = PreferencesSnapshot(
            preventDisplaySleep: false,
            preventLidCloseSleep: true,
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
            playLidEventSounds: true
        )

        let row = PreferenceMenuRows.rows(for: snapshot)
            .first { $0.id == .playLidEventSounds }

        XCTAssertEqual(row?.isOn, true)
        XCTAssertEqual(row?.isEnabled, false)
        XCTAssertEqual(row?.isChild, true)
    }

    func testDiskSleepRowAppearsWhenShowDiskSleepIsTrue() {
        let snapshot = PreferencesSnapshot(
            preventDisplaySleep: true,
            preventLidCloseSleep: false,
            preventDiskSleep: true,
            playLidEventSounds: true
        )

        let rows = PreferenceMenuRows.rows(for: snapshot, showDiskSleep: true)

        XCTAssertEqual(rows.map(\.id), [
            .preventDisplaySleep,
            .preventDiskSleep,
            .preventLidCloseSleep,
            .playLidEventSounds,
        ])

        let row = rows.first { $0.id == .preventDiskSleep }
        XCTAssertEqual(row?.title, "Prevent disk sleep")
        XCTAssertEqual(row?.isOn, true)
        XCTAssertEqual(row?.isEnabled, true)
        XCTAssertEqual(row?.isChild, false)
    }

    func testDiskSleepRowHiddenByDefault() {
        let snapshot = PreferencesSnapshot(
            preventDisplaySleep: true,
            preventLidCloseSleep: false,
            preventDiskSleep: true,
            playLidEventSounds: true
        )

        let rows = PreferenceMenuRows.rows(for: snapshot)

        XCTAssertEqual(rows.map(\.id), [
            .preventDisplaySleep,
            .preventLidCloseSleep,
            .playLidEventSounds,
        ])
    }
}
