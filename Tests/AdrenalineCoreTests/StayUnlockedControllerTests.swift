import XCTest
@testable import AdrenalineCore

private final class FakeScreenLockSetting: ScreenLockSettingControlling {
    var delay: ScreenLockDelay = .immediate
    var acceptedPassword = "right"
    private(set) var setCalls: [(ScreenLockDelay, String)] = []

    func currentDelay() throws -> ScreenLockDelay { delay }

    func setDelay(_ delay: ScreenLockDelay, password: String) throws {
        setCalls.append((delay, password))
        guard password == acceptedPassword else {
            throw ScreenLockSettingError.changeRejected("Password is required!")
        }
        self.delay = delay
    }
}

private final class FakePasswordStore: PasswordStoring {
    var password: String?
    func read() -> String? { password }
    func save(_ password: String) throws { self.password = password }
}

private final class FakePreferences: PreferencesProviding {
    var preventDisplaySleep = true
    var preventLidCloseSleep = true
    var preventDiskSleep = true
    var playLidEventSounds = true
    var overrideSystemVolumeForLidEventSounds = true
    var stayUnlockedWithLidClosed = true
    var lidClosePreventionConfirmed = false
    var wasActive = false

    func snapshot() -> PreferencesSnapshot {
        PreferencesSnapshot(
            preventDisplaySleep: preventDisplaySleep,
            preventLidCloseSleep: preventLidCloseSleep,
            playLidEventSounds: playLidEventSounds,
            stayUnlockedWithLidClosed: stayUnlockedWithLidClosed
        )
    }
}

final class StayUnlockedControllerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AdrenalineTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func make(
        storedPassword: String? = "right",
        prompts: [String?] = []
    ) -> (AppState, FakePreferences, FakeScreenLockSetting, FakePasswordStore, StayUnlockedController, () -> [Bool]) {
        let state = AppState()
        let prefs = FakePreferences()
        let setting = FakeScreenLockSetting()
        let store = FakePasswordStore()
        store.password = storedPassword
        var remaining = prompts
        var promptRetries: [Bool] = []
        let controller = StayUnlockedController(
            state: state,
            preferences: prefs,
            setting: setting,
            passwordStore: store,
            defaults: defaults,
            requestPassword: { retry in
                promptRetries.append(retry)
                return remaining.isEmpty ? nil : remaining.removeFirst()
            }
        )
        return (state, prefs, setting, store, controller, { promptRetries })
    }

    func testTurningOnDisablesLockAndTurningOffRestoresIt() {
        let (state, _, setting, _, controller, _) = make()
        setting.delay = .seconds(300)

        state.setActive(true)
        XCTAssertEqual(setting.delay, .off)
        XCTAssertTrue(controller.isEngaged)

        state.setActive(false)
        XCTAssertEqual(setting.delay, .seconds(300))
        XCTAssertFalse(controller.isEngaged)
    }

    func testDoesNothingWhenPreferenceOffOrLidClosePreventionOff() {
        let (state, prefs, setting, _, controller, _) = make()
        prefs.stayUnlockedWithLidClosed = false
        state.setActive(true)
        XCTAssertEqual(setting.delay, .immediate)

        prefs.stayUnlockedWithLidClosed = true
        prefs.preventLidCloseSleep = false
        controller.apply()
        XCTAssertEqual(setting.delay, .immediate)
        XCTAssertTrue(setting.setCalls.isEmpty)
    }

    func testUncheckingPreferenceWhileActiveRestores() {
        let (state, prefs, setting, _, controller, _) = make()
        state.setActive(true)
        XCTAssertEqual(setting.delay, .off)

        prefs.stayUnlockedWithLidClosed = false
        controller.apply()
        XCTAssertEqual(setting.delay, .immediate)
    }

    func testAlreadyOffIsLeftAloneAndNotRestored() {
        let (state, _, setting, _, controller, _) = make()
        setting.delay = .off

        state.setActive(true)
        state.setActive(false)

        XCTAssertTrue(setting.setCalls.isEmpty)
        XCTAssertFalse(controller.isEngaged)
    }

    func testMissingPasswordPromptsAndSavesIt() {
        let (state, _, setting, store, controller, retries) = make(storedPassword: nil, prompts: ["right"])
        defer { _ = controller }

        state.setActive(true)

        XCTAssertEqual(setting.delay, .off)
        XCTAssertEqual(store.password, "right")
        XCTAssertEqual(retries(), [false])
    }

    func testWrongStoredPasswordRepromptsAsRetry() {
        let (state, _, setting, store, controller, retries) = make(storedPassword: "stale", prompts: ["right"])
        defer { _ = controller }

        state.setActive(true)

        XCTAssertEqual(setting.delay, .off)
        XCTAssertEqual(store.password, "right")
        XCTAssertEqual(retries(), [true])
    }

    func testCancellingPromptUnchecksPreferenceAndLeavesSettingAlone() {
        let (state, prefs, setting, _, controller, _) = make(storedPassword: nil, prompts: [nil])

        state.setActive(true)

        XCTAssertEqual(setting.delay, .immediate)
        XCTAssertFalse(prefs.stayUnlockedWithLidClosed)
        XCTAssertFalse(controller.isEngaged)
        XCTAssertNil(state.lastErrorMessage)
    }

    func testSavedOriginalSurvivesRelaunchAndIsRestored() {
        let (state, _, setting, _, original, _) = make()
        state.setActive(true)
        XCTAssertEqual(setting.delay, .off)
        _ = original

        // Simulate a crash: a fresh controller on the same defaults, app not active.
        let store = FakePasswordStore()
        store.password = "right"
        let relaunched = StayUnlockedController(
            state: AppState(),
            preferences: FakePreferences(),
            setting: setting,
            passwordStore: store,
            defaults: defaults,
            requestPassword: { _ in nil }
        )
        XCTAssertTrue(relaunched.isEngaged)

        relaunched.apply()
        XCTAssertEqual(setting.delay, .immediate)
        XCTAssertFalse(relaunched.isEngaged)
    }

    func testStatusOutputParsing() {
        XCTAssertEqual(ScreenLockDelay.parse(statusOutput: "2026-09-26 sysadminctl[1:2] screenLock delay is immediate"), .immediate)
        XCTAssertEqual(ScreenLockDelay.parse(statusOutput: "2026-09-26 sysadminctl[1:2] screenLock is off"), .off)
        XCTAssertEqual(ScreenLockDelay.parse(statusOutput: "screenLock delay is 300 seconds"), .seconds(300))
        XCTAssertNil(ScreenLockDelay.parse(statusOutput: "something else"))
    }

    func testDelayArgumentRoundTrips() {
        for delay in [ScreenLockDelay.off, .immediate, .seconds(60)] {
            XCTAssertEqual(ScreenLockDelay(argument: delay.argument), delay)
        }
    }
}
