import Combine
import XCTest
@testable import InsomniaCore

private final class FakeAwakeController: AwakeControlling {
    var isEnabled = false
    var enableError: Error?
    var enableCallCount = 0
    var disableCallCount = 0
    var lastPreventDisplaySleep: Bool?
    var preventDisplaySleepHistory: [Bool] = []
    var setPreventDisplaySleepError: Error?

    func enable() throws {
        try enable(preventDisplaySleep: true)
    }

    func enable(preventDisplaySleep: Bool) throws {
        enableCallCount += 1
        lastPreventDisplaySleep = preventDisplaySleep
        if let enableError { throw enableError }
        isEnabled = true
    }

    func setPreventDisplaySleep(_ enabled: Bool) throws {
        if let setPreventDisplaySleepError { throw setPreventDisplaySleepError }
        preventDisplaySleepHistory.append(enabled)
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
    var statusValue = true
    var enableCallCount = 0
    var disableCallCount = 0

    func enable() async throws {
        enableCallCount += 1
        if let enableError { throw enableError }
        isEnabled = true
    }

    func disable() async throws {
        disableCallCount += 1
        if let disableError { throw disableError }
        isEnabled = false
    }

    func status() async throws -> Bool {
        statusValue
    }
}

private final class SuspendedEnableLidCloseController: LidCloseControlling {
    var isEnabled = false
    var statusValue = true
    var disableCallCount = 0
    var events: [String] = []

    let enableStarted = XCTestExpectation(description: "lid-close enable started")
    private var enableContinuation: CheckedContinuation<Void, Never>?

    func enable() async throws {
        events.append("enable-start")
        enableStarted.fulfill()
        await withCheckedContinuation { continuation in
            enableContinuation = continuation
        }
        events.append("enable-resume")
        isEnabled = true
    }

    func resumeEnable() {
        enableContinuation?.resume()
        enableContinuation = nil
    }

    func disable() async throws {
        events.append("disable")
        disableCallCount += 1
        isEnabled = false
    }

    func status() async throws -> Bool {
        events.append("status")
        return statusValue
    }
}

@MainActor
private final class FakePreferencesStore: PreferencesProviding {
    @Published var preventDisplaySleep: Bool = true
    @Published var preventLidCloseSleep: Bool = false
    @Published var playLidEventSounds: Bool = true
    @Published var lidClosePreventionConfirmed: Bool = false

    var preventDisplaySleepPublisher: AnyPublisher<Bool, Never> { $preventDisplaySleep.eraseToAnyPublisher() }
    var preventLidCloseSleepPublisher: AnyPublisher<Bool, Never> { $preventLidCloseSleep.eraseToAnyPublisher() }
    var playLidEventSoundsPublisher: AnyPublisher<Bool, Never> { $playLidEventSounds.eraseToAnyPublisher() }

    func snapshot() -> PreferencesSnapshot {
        PreferencesSnapshot(
            preventDisplaySleep: preventDisplaySleep,
            preventLidCloseSleep: preventLidCloseSleep,
            playLidEventSounds: playLidEventSounds
        )
    }
}

private struct TestError: Error, LocalizedError {
    let errorDescription: String?
}

@MainActor
final class AppCoordinatorTests: XCTestCase {
    func testTurnOnSkipsLidCloseWhenPreferenceOff() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = false
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.turnOn()

        XCTAssertTrue(state.isActive)
        XCTAssertEqual(awake.enableCallCount, 1)
        XCTAssertEqual(awake.lastPreventDisplaySleep, true)
        XCTAssertEqual(lid.enableCallCount, 0)
    }

    func testTurnOnRespectsDisplaySleepPreference() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventDisplaySleep = false
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.turnOn()

        XCTAssertEqual(awake.lastPreventDisplaySleep, false)
        XCTAssertEqual(lid.enableCallCount, 0)
    }

    func testTurnOffSkipsLidCloseWhenNotEngagedThisSession() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = false
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.turnOn()
        await coordinator.turnOff()

        XCTAssertEqual(lid.disableCallCount, 0)
        XCTAssertFalse(state.isActive)
    }

    func testSetPreventDisplaySleepWhileOnReconcilesAwakeController() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.turnOn()
        await coordinator.setPreventDisplaySleep(false)

        XCTAssertEqual(awake.preventDisplaySleepHistory, [false])
        XCTAssertFalse(prefs.preventDisplaySleep)
    }

    func testSetPreventDisplaySleepWhileOffJustPersists() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.setPreventDisplaySleep(false)

        XCTAssertEqual(awake.preventDisplaySleepHistory, [])
        XCTAssertFalse(prefs.preventDisplaySleep)
    }

    func testSetPreventLidCloseSleepWhileOnEngagesHelper() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.turnOn()
        XCTAssertEqual(lid.enableCallCount, 0)

        await coordinator.setPreventLidCloseSleep(true)

        XCTAssertEqual(lid.enableCallCount, 1)
        XCTAssertTrue(prefs.preventLidCloseSleep)
        XCTAssertTrue(lid.isEnabled)
    }

    func testSetPreventLidCloseSleepRevertsPreferenceOnEnableFailure() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        lid.enableError = TestError(errorDescription: "helper refused")
        let prefs = FakePreferencesStore()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.turnOn()
        await coordinator.setPreventLidCloseSleep(true)

        XCTAssertFalse(prefs.preventLidCloseSleep)
        XCTAssertEqual(state.lastErrorMessage, "helper refused")
        XCTAssertTrue(state.isActive, "Awake stays enabled when only the lid-close reconciliation fails")
        XCTAssertTrue(awake.isEnabled)
    }

    func testSetPreventLidCloseSleepWhileOnDisablesHelperWhenTurnedOff() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.turnOn()
        XCTAssertEqual(lid.enableCallCount, 1)

        await coordinator.setPreventLidCloseSleep(false)

        XCTAssertEqual(lid.disableCallCount, 1)
        XCTAssertFalse(prefs.preventLidCloseSleep)
    }

    func testSetPreventLidCloseSleepDisableFailureKeepsActiveAndLeavesPreferenceOff() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        lid.disableError = TestError(errorDescription: "disable failed")
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.turnOn()
        XCTAssertTrue(state.isActive)
        XCTAssertTrue(awake.isEnabled)
        XCTAssertEqual(lid.enableCallCount, 1)

        await coordinator.setPreventLidCloseSleep(false)

        XCTAssertFalse(prefs.preventLidCloseSleep)
        XCTAssertTrue(state.isActive, "ordinary awake assertions remain active, so UI must stay active-with-error")
        XCTAssertEqual(state.lastErrorMessage, "disable failed")
        XCTAssertTrue(awake.isEnabled)
        XCTAssertEqual(lid.disableCallCount, 1)
    }

    func testSetPreventLidCloseSleepStatusStillActiveAfterDisableKeepsActiveAndRecordsError() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.turnOn()
        lid.statusValue = true

        await coordinator.setPreventLidCloseSleep(false)

        XCTAssertFalse(prefs.preventLidCloseSleep)
        XCTAssertTrue(state.isActive, "ordinary awake assertions remain active, so UI must stay active-with-error")
        XCTAssertEqual(state.lastErrorMessage, "Lid-close prevention remained active after disable")
        XCTAssertTrue(awake.isEnabled)
        XCTAssertEqual(lid.disableCallCount, 1)
    }

    func testToggleOnEnablesAwakeAndLidCloseAndMarksActive() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.toggle()

        XCTAssertTrue(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertTrue(awake.isEnabled)
        XCTAssertTrue(lid.isEnabled)
        XCTAssertEqual(awake.enableCallCount, 1)
        XCTAssertEqual(lid.enableCallCount, 1)
        XCTAssertNil(state.lastErrorMessage)
    }

    func testToggleDoesNothingWhenStateIsBusy() async {
        let state = AppState(isBusy: true)
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: FakePreferencesStore())

        await coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertTrue(state.isBusy)
        XCTAssertEqual(awake.enableCallCount, 0)
        XCTAssertEqual(awake.disableCallCount, 0)
        XCTAssertEqual(lid.enableCallCount, 0)
        XCTAssertEqual(lid.disableCallCount, 0)
    }

    func testToggleOffDisablesAwakeAndLidClose() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.turnOn()
        await coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertFalse(lid.isEnabled)
        XCTAssertEqual(awake.disableCallCount, 1)
        XCTAssertEqual(lid.disableCallCount, 1)
    }

    func testToggleOffRecordsErrorWhenLidCloseRemainsActiveAfterDisable() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.turnOn()
        lid.statusValue = true
        await coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertEqual(state.lastErrorMessage, "Lid-close prevention remained active after disable")
        XCTAssertFalse(awake.isEnabled)
        XCTAssertEqual(lid.disableCallCount, 1)
    }

    func testShutdownCleanupDisablesControllersEvenWhenBusy() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.turnOn()
        state.setBusy(true)
        lid.statusValue = false
        await coordinator.shutdownCleanup()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertFalse(lid.isEnabled)
        XCTAssertEqual(awake.disableCallCount, 1)
        XCTAssertEqual(lid.disableCallCount, 1)
        XCTAssertNil(state.lastErrorMessage)
    }

    func testShutdownCleanupRecordsErrorAndEndsInactiveIdleWhenLidCloseRemainsActive() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.turnOn()
        state.setBusy(true)
        lid.statusValue = true
        await coordinator.shutdownCleanup()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertEqual(lid.disableCallCount, 1)
        XCTAssertEqual(state.lastErrorMessage, "Lid-close prevention remained active after disable")
        XCTAssertEqual(state.helperState, .failed(message: "Lid-close prevention remained active after disable"))
    }

    func testShutdownCleanupAttemptsBestEffortDisableWhenInactiveButBusy() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.turnOn()
        state.setActive(false)
        state.setBusy(true)
        lid.statusValue = false
        await coordinator.shutdownCleanup()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertFalse(lid.isEnabled)
        XCTAssertEqual(awake.disableCallCount, 1)
        XCTAssertEqual(lid.disableCallCount, 1)
    }

    func testShutdownCleanupPreventsSuspendedTurnOnFromReactivating() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = SuspendedEnableLidCloseController()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        let turnOnTask = Task { await coordinator.turnOn() }
        await fulfillment(of: [lid.enableStarted], timeout: 1)

        let shutdownTask = Task { await coordinator.shutdownCleanup() }
        await Task.yield()

        lid.resumeEnable()
        await turnOnTask.value
        await shutdownTask.value

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertFalse(lid.isEnabled)
        XCTAssertGreaterThanOrEqual(lid.disableCallCount, 1)
        XCTAssertGreaterThan(
            lid.events.lastIndex(of: "disable") ?? -1,
            lid.events.lastIndex(of: "enable-resume") ?? -1,
            "shutdown cleanup must perform final disable after suspended enable resumes"
        )
    }

    func testLidCloseFailureRollsBackAwakeAndLeavesStateOff() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        lid.enableError = TestError(errorDescription: "helper refused")
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertEqual(awake.disableCallCount, 1)
        XCTAssertEqual(lid.disableCallCount, 1)
        XCTAssertEqual(state.lastErrorMessage, "helper refused")
        XCTAssertEqual(state.helperState, .failed(message: "helper refused"))
    }

    func testFalseStatusAfterEnableRollsBack() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        lid.statusValue = false
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: prefs)

        await coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertEqual(state.lastErrorMessage, "Lid-close prevention did not become active")
        XCTAssertEqual(state.helperState, .failed(message: "Lid-close prevention did not become active"))
    }
}
