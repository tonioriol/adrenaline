import XCTest
@testable import AdrenalineCore

private final class FakeAwakeController: AwakeControlling {
    var isEnabled = false
    var enableError: Error?
    var enableCallCount = 0
    var disableCallCount = 0
    var lastPreventDisplaySleep: Bool?
    var lastPreventDiskSleep: Bool?
    var preventDisplaySleepHistory: [Bool] = []
    var preventDiskSleepHistory: [Bool] = []
    var setPreventDisplaySleepError: Error?
    var setPreventDiskSleepError: Error?

    func enable() throws {
        try enable(preventDisplaySleep: true, preventDiskSleep: false)
    }

    func enable(preventDisplaySleep: Bool) throws {
        try enable(preventDisplaySleep: preventDisplaySleep, preventDiskSleep: false)
    }

    func enable(preventDisplaySleep: Bool, preventDiskSleep: Bool) throws {
        enableCallCount += 1
        lastPreventDisplaySleep = preventDisplaySleep
        lastPreventDiskSleep = preventDiskSleep
        if let enableError { throw enableError }
        isEnabled = true
    }

    func setPreventDisplaySleep(_ enabled: Bool) throws {
        if let setPreventDisplaySleepError { throw setPreventDisplaySleepError }
        preventDisplaySleepHistory.append(enabled)
    }

    func setPreventDiskSleep(_ enabled: Bool) throws {
        if let setPreventDiskSleepError { throw setPreventDiskSleepError }
        preventDiskSleepHistory.append(enabled)
    }

    func disable() {
        disableCallCount += 1
        isEnabled = false
    }
}

private final class FakeLidCloseController: LidCloseControlling {
    var isEnabled = false
    var enableError: Error?
    var disableError: Error?
    var statusValue: Bool?
    var enableCallCount = 0
    var disableCallCount = 0

    func enable(completion: @escaping (Error?) -> Void) {
        enableCallCount += 1
        if let enableError {
            completion(enableError)
            return
        }
        isEnabled = true
        completion(nil)
    }

    func disable(completion: @escaping (Error?) -> Void) {
        disableCallCount += 1
        if let disableError {
            completion(disableError)
            return
        }
        isEnabled = false
        completion(nil)
    }

    func status(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(statusValue ?? isEnabled))
    }
}

private final class FakePreferencesStore: PreferencesProviding {
    var preventDisplaySleep: Bool = true
    var preventLidCloseSleep: Bool = false
    var preventDiskSleep: Bool = true
    var playLidEventSounds: Bool = true
    var overrideSystemVolumeForLidEventSounds: Bool = true
    var lidClosePreventionConfirmed: Bool = false
    var wasActive: Bool = false

    func snapshot() -> PreferencesSnapshot {
        PreferencesSnapshot(
            preventDisplaySleep: preventDisplaySleep,
            preventLidCloseSleep: preventLidCloseSleep,
            preventDiskSleep: preventDiskSleep,
            playLidEventSounds: playLidEventSounds,
            overrideSystemVolumeForLidEventSounds: overrideSystemVolumeForLidEventSounds
        )
    }
}

private struct TestError: Error, LocalizedError {
    let errorDescription: String?
}

final class AppCoordinatorTests: XCTestCase {
    func testTurnOnSkipsLidCloseWhenPreferenceOff() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = false
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.turnOn()

        XCTAssertTrue(state.isActive)
        XCTAssertEqual(awake.enableCallCount, 1)
        XCTAssertEqual(awake.lastPreventDisplaySleep, true)
        XCTAssertEqual(lid.enableCallCount, 0)
    }

    func testTurnOnRespectsDisplaySleepPreference() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventDisplaySleep = false
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.turnOn()

        XCTAssertEqual(awake.lastPreventDisplaySleep, false)
        XCTAssertEqual(lid.enableCallCount, 0)
    }

    func testTurnOffSkipsLidCloseWhenNotEngagedThisSession() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = false
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.turnOn()
        coordinator.turnOff()

        XCTAssertEqual(lid.disableCallCount, 0)
        XCTAssertFalse(state.isActive)
    }

    func testSetPreventDisplaySleepWhileOnReconcilesAwakeController() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.turnOn()
        coordinator.setPreventDisplaySleep(false)

        XCTAssertEqual(awake.preventDisplaySleepHistory, [false])
        XCTAssertFalse(prefs.preventDisplaySleep)
    }

    func testSetPreventDisplaySleepWhileOffJustPersists() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.setPreventDisplaySleep(false)

        XCTAssertEqual(awake.preventDisplaySleepHistory, [])
        XCTAssertFalse(prefs.preventDisplaySleep)
    }

    func testSetPreventLidCloseSleepWhileOnEngagesHelper() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.turnOn()
        XCTAssertEqual(lid.enableCallCount, 0)

        coordinator.setPreventLidCloseSleep(true)

        XCTAssertEqual(lid.enableCallCount, 1)
        XCTAssertTrue(prefs.preventLidCloseSleep)
        XCTAssertTrue(lid.isEnabled)
    }

    func testSetPreventLidCloseSleepRevertsPreferenceOnEnableFailure() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        lid.enableError = TestError(errorDescription: "helper refused")
        let prefs = FakePreferencesStore()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.turnOn()
        coordinator.setPreventLidCloseSleep(true)

        XCTAssertFalse(prefs.preventLidCloseSleep)
        XCTAssertEqual(state.lastErrorMessage, "helper refused")
        XCTAssertTrue(state.isActive, "Awake stays enabled when only the lid-close reconciliation fails")
        XCTAssertTrue(awake.isEnabled)
    }

    func testSetPreventLidCloseSleepWhileOnDisablesHelperWhenTurnedOff() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.turnOn()
        XCTAssertEqual(lid.enableCallCount, 1)

        coordinator.setPreventLidCloseSleep(false)

        XCTAssertEqual(lid.disableCallCount, 1)
        XCTAssertFalse(prefs.preventLidCloseSleep)
    }

    func testSetPreventLidCloseSleepDisableFailureKeepsActiveAndLeavesPreferenceOff() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        lid.disableError = TestError(errorDescription: "disable failed")
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.turnOn()
        XCTAssertTrue(state.isActive)
        XCTAssertTrue(awake.isEnabled)
        XCTAssertEqual(lid.enableCallCount, 1)

        coordinator.setPreventLidCloseSleep(false)

        XCTAssertFalse(prefs.preventLidCloseSleep)
        XCTAssertTrue(state.isActive, "ordinary awake assertions remain active, so UI must stay active-with-error")
        XCTAssertEqual(state.lastErrorMessage, "disable failed")
        XCTAssertTrue(awake.isEnabled)
        XCTAssertEqual(lid.disableCallCount, 1)
    }

    func testSetPreventLidCloseSleepStatusStillActiveAfterDisableKeepsActiveAndRecordsError() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.turnOn()
        lid.statusValue = true

        coordinator.setPreventLidCloseSleep(false)

        XCTAssertFalse(prefs.preventLidCloseSleep)
        XCTAssertTrue(state.isActive, "ordinary awake assertions remain active, so UI must stay active-with-error")
        XCTAssertEqual(state.lastErrorMessage, "Lid-close prevention remained active after disable")
        XCTAssertTrue(awake.isEnabled)
        XCTAssertEqual(lid.disableCallCount, 1)
    }

    func testToggleOnEnablesAwakeAndLidCloseAndMarksActive() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.toggle()

        XCTAssertTrue(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertTrue(awake.isEnabled)
        XCTAssertTrue(lid.isEnabled)
        XCTAssertEqual(awake.enableCallCount, 1)
        XCTAssertEqual(lid.enableCallCount, 1)
        XCTAssertNil(state.lastErrorMessage)
    }

    func testToggleDoesNothingWhenStateIsBusy() {
        let state = AppState(isBusy: true)
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: FakePreferencesStore())

        coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertTrue(state.isBusy)
        XCTAssertEqual(awake.enableCallCount, 0)
        XCTAssertEqual(awake.disableCallCount, 0)
        XCTAssertEqual(lid.enableCallCount, 0)
        XCTAssertEqual(lid.disableCallCount, 0)
    }

    func testToggleOffDisablesAwakeAndLidClose() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.turnOn()
        coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertFalse(lid.isEnabled)
        XCTAssertEqual(awake.disableCallCount, 1)
        XCTAssertEqual(lid.disableCallCount, 1)
    }

    func testToggleOffRecordsErrorWhenLidCloseRemainsActiveAfterDisable() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.turnOn()
        lid.statusValue = true
        coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertEqual(state.lastErrorMessage, "Lid-close prevention remained active after disable")
        XCTAssertFalse(awake.isEnabled)
        XCTAssertEqual(lid.disableCallCount, 1)
    }

    func testShutdownCleanupDisablesControllersEvenWhenBusy() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.turnOn()
        state.setBusy(true)
        coordinator.shutdownCleanup { }

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertFalse(lid.isEnabled)
        XCTAssertEqual(awake.disableCallCount, 1)
        XCTAssertEqual(lid.disableCallCount, 1)
        XCTAssertNil(state.lastErrorMessage)
    }

    func testShutdownCleanupRecordsErrorAndEndsInactiveIdleWhenLidCloseRemainsActive() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.turnOn()
        state.setBusy(true)
        lid.statusValue = true
        coordinator.shutdownCleanup { }

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertEqual(lid.disableCallCount, 1)
        XCTAssertEqual(state.lastErrorMessage, "Lid-close prevention remained active after disable")
        XCTAssertEqual(state.helperState, .failed(message: "Lid-close prevention remained active after disable"))
    }

    func testShutdownCleanupAttemptsBestEffortDisableWhenInactiveButBusy() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.turnOn()
        state.setActive(false)
        state.setBusy(true)
        coordinator.shutdownCleanup { }

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertFalse(lid.isEnabled)
        XCTAssertEqual(awake.disableCallCount, 1)
        XCTAssertEqual(lid.disableCallCount, 1)
    }

    func testLidCloseFailureRollsBackAwakeAndLeavesStateOff() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        lid.enableError = TestError(errorDescription: "helper refused")
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertEqual(awake.disableCallCount, 1)
        XCTAssertEqual(lid.disableCallCount, 0)
        XCTAssertEqual(state.lastErrorMessage, "helper refused")
        XCTAssertEqual(state.helperState, .failed(message: "helper refused"))
    }

    func testFalseStatusAfterEnableRollsBack() {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        lid.statusValue = false
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertEqual(state.lastErrorMessage, "Lid-close prevention did not become active")
        XCTAssertEqual(state.helperState, .failed(message: "Lid-close prevention did not become active"))
    }
}
