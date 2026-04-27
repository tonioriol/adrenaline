import XCTest
@testable import InsomniaCore

@MainActor
final class MacOSLockPolicyReaderTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDown() {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles = []
        super.tearDown()
    }

    func testRequirePasswordDisabledProducesNoLockDelay() throws {
        let reader = makeReader(
            screenSaverValues: ["askForPassword": 0, "askForPasswordDelay": 0],
            batteryDisplayMinutes: 1,
            acDisplayMinutes: 5,
            powerSource: .battery
        )

        let policy = try reader.currentPolicy()

        XCTAssertFalse(policy.requiresPassword)
        XCTAssertEqual(policy.displaySleepDelay, 60)
        XCTAssertEqual(policy.passwordDelay, 0)
        XCTAssertNil(policy.lockDelay)
    }

    func testMissingRequirePasswordProducesNoLockDelay() throws {
        let reader = makeReader(
            screenSaverValues: ["askForPasswordDelay": 0],
            batteryDisplayMinutes: 1,
            acDisplayMinutes: 5,
            powerSource: .battery
        )

        let policy = try reader.currentPolicy()

        XCTAssertFalse(policy.requiresPassword)
        XCTAssertNil(policy.lockDelay)
    }

    func testImmediatePasswordUsesDisplayTimerOnly() throws {
        let reader = makeReader(
            screenSaverValues: ["askForPassword": 1, "askForPasswordDelay": 0],
            batteryDisplayMinutes: 1,
            acDisplayMinutes: 5,
            powerSource: .battery
        )

        let policy = try reader.currentPolicy()
        XCTAssertTrue(policy.requiresPassword)
        XCTAssertEqual(policy.displaySleepDelay, 60)
        XCTAssertEqual(policy.passwordDelay, 0)
        XCTAssertEqual(policy.lockDelay, 60)
    }

    func testPasswordDelayIsAddedToDisplayTimer() throws {
        let reader = makeReader(
            screenSaverValues: ["askForPassword": 1, "askForPasswordDelay": 5],
            batteryDisplayMinutes: 1,
            acDisplayMinutes: 5,
            powerSource: .ac
        )

        let policy = try reader.currentPolicy()
        XCTAssertTrue(policy.requiresPassword)
        XCTAssertEqual(policy.displaySleepDelay, 300)
        XCTAssertEqual(policy.passwordDelay, 5)
        XCTAssertEqual(policy.lockDelay, 305)
    }

    func testBatteryPowerUsesBatteryDisplayTimer() throws {
        let reader = makeReader(
            screenSaverValues: ["askForPassword": 1, "askForPasswordDelay": 0],
            batteryDisplayMinutes: 2,
            acDisplayMinutes: 9,
            powerSource: .battery
        )

        let policy = try reader.currentPolicy()
        XCTAssertEqual(policy.displaySleepDelay, 120)
        XCTAssertEqual(policy.lockDelay, 120)
    }

    func testACPowerUsesACDisplayTimer() throws {
        let reader = makeReader(
            screenSaverValues: ["askForPassword": 1, "askForPasswordDelay": 0],
            batteryDisplayMinutes: 2,
            acDisplayMinutes: 9,
            powerSource: .ac
        )

        let policy = try reader.currentPolicy()
        XCTAssertEqual(policy.displaySleepDelay, 540)
        XCTAssertEqual(policy.lockDelay, 540)
    }

    func testUnknownPowerSourceFallsBackToBatteryTimer() throws {
        let reader = makeReader(
            screenSaverValues: ["askForPassword": 1, "askForPasswordDelay": 0],
            batteryDisplayMinutes: 3,
            acDisplayMinutes: 8,
            powerSource: nil
        )

        let policy = try reader.currentPolicy()
        XCTAssertEqual(policy.displaySleepDelay, 180)
        XCTAssertEqual(policy.lockDelay, 180)
    }

    func testDisplayTimerZeroProducesNoLockDelay() throws {
        let reader = makeReader(
            screenSaverValues: ["askForPassword": 1, "askForPasswordDelay": 0],
            batteryDisplayMinutes: 0,
            acDisplayMinutes: 5,
            powerSource: .battery
        )

        let policy = try reader.currentPolicy()
        XCTAssertTrue(policy.requiresPassword)
        XCTAssertEqual(policy.displaySleepDelay, 0)
        XCTAssertNil(policy.lockDelay)
    }

    func testNegativePasswordDelayIsTreatedAsZero() throws {
        let reader = makeReader(
            screenSaverValues: ["askForPassword": 1, "askForPasswordDelay": -10],
            batteryDisplayMinutes: 1,
            acDisplayMinutes: 5,
            powerSource: .battery
        )

        let policy = try reader.currentPolicy()
        XCTAssertEqual(policy.passwordDelay, 0)
        XCTAssertEqual(policy.lockDelay, 60)
    }

    func testUnreadablePowerSettingsThrowsReadError() {
        let suiteName = "MacOSLockPolicyReaderTests.unreadable.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(1, forKey: "askForPassword")
        defaults.set(0, forKey: "askForPasswordDelay")
        let missingURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("missing-power-settings-\(UUID().uuidString).plist")
        let reader = MacOSLockPolicyReader(
            screenSaverDefaults: defaults,
            powerSettingsURL: missingURL,
            powerSourceProvider: { .battery }
        )

        XCTAssertThrowsError(try reader.currentPolicy()) { error in
            XCTAssertEqual(error as? MacOSLockPolicyReaderError, .powerSettingsUnreadable)
        }
    }

    private func makeReader(
        screenSaverValues: [String: Any],
        batteryDisplayMinutes: Int,
        acDisplayMinutes: Int,
        powerSource: MacOSPowerSource?
    ) -> MacOSLockPolicyReader {
        let suiteName = "MacOSLockPolicyReaderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        for (key, value) in screenSaverValues {
            defaults.set(value, forKey: key)
        }

        let powerSettingsURL = writePowerSettingsPlist(
            batteryDisplayMinutes: batteryDisplayMinutes,
            acDisplayMinutes: acDisplayMinutes
        )

        return MacOSLockPolicyReader(
            screenSaverDefaults: defaults,
            powerSettingsURL: powerSettingsURL,
            powerSourceProvider: { powerSource }
        )
    }

    private func writePowerSettingsPlist(batteryDisplayMinutes: Int, acDisplayMinutes: Int) -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("power-settings-\(UUID().uuidString).plist")
        let plist: [String: Any] = [
            "Battery Power": ["Display Sleep Timer": batteryDisplayMinutes],
            "AC Power": ["Display Sleep Timer": acDisplayMinutes],
        ]
        let data = try! PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try! data.write(to: url)
        temporaryFiles.append(url)
        return url
    }
}
