import XCTest
@testable import CocaineCore

private final class FakeAwakeController: AwakeControlling {
    var isEnabled = false
    var enableError: Error?
    var enableCallCount = 0
    var disableCallCount = 0

    func enable() throws {
        enableCallCount += 1
        if let enableError { throw enableError }
        isEnabled = true
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

private struct TestError: Error, LocalizedError {
    let errorDescription: String?
}

@MainActor
final class AppCoordinatorTests: XCTestCase {
    func testToggleOnEnablesAwakeAndLidCloseAndMarksActive() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid)

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
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid)

        await coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertTrue(state.isBusy)
        XCTAssertEqual(awake.enableCallCount, 0)
        XCTAssertEqual(awake.disableCallCount, 0)
        XCTAssertEqual(lid.enableCallCount, 0)
        XCTAssertEqual(lid.disableCallCount, 0)
    }

    func testToggleOffDisablesAwakeAndLidClose() async {
        let state = AppState(isActive: true)
        let awake = FakeAwakeController()
        awake.isEnabled = true
        let lid = FakeLidCloseController()
        lid.isEnabled = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid)

        await coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertFalse(lid.isEnabled)
        XCTAssertEqual(awake.disableCallCount, 1)
        XCTAssertEqual(lid.disableCallCount, 1)
    }

    func testToggleOffRecordsErrorWhenLidCloseRemainsActiveAfterDisable() async {
        let state = AppState(isActive: true)
        let awake = FakeAwakeController()
        awake.isEnabled = true
        let lid = FakeLidCloseController()
        lid.isEnabled = true
        lid.statusValue = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid)

        await coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertEqual(state.lastErrorMessage, "Lid-close prevention remained active after disable")
        XCTAssertFalse(awake.isEnabled)
        XCTAssertEqual(lid.disableCallCount, 1)
    }

    func testShutdownCleanupDisablesControllersEvenWhenBusy() async {
        let state = AppState(isActive: true, isBusy: true)
        let awake = FakeAwakeController()
        awake.isEnabled = true
        let lid = FakeLidCloseController()
        lid.isEnabled = true
        lid.statusValue = false
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid)

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
        let state = AppState(isActive: true, isBusy: true)
        let awake = FakeAwakeController()
        awake.isEnabled = true
        let lid = FakeLidCloseController()
        lid.isEnabled = true
        lid.statusValue = true
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid)

        await coordinator.shutdownCleanup()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertEqual(lid.disableCallCount, 1)
        XCTAssertEqual(state.lastErrorMessage, "Lid-close prevention remained active after disable")
        XCTAssertEqual(state.helperState, .failed(message: "Lid-close prevention remained active after disable"))
    }

    func testShutdownCleanupAttemptsBestEffortDisableWhenInactiveButBusy() async {
        let state = AppState(isActive: false, isBusy: true)
        let awake = FakeAwakeController()
        awake.isEnabled = true
        let lid = FakeLidCloseController()
        lid.isEnabled = true
        lid.statusValue = false
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid)

        await coordinator.shutdownCleanup()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertFalse(lid.isEnabled)
        XCTAssertEqual(awake.disableCallCount, 1)
        XCTAssertEqual(lid.disableCallCount, 1)
    }

    func testLidCloseFailureRollsBackAwakeAndLeavesStateOff() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        lid.enableError = TestError(errorDescription: "helper refused")
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid)

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
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid)

        await coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertEqual(state.lastErrorMessage, "Lid-close prevention did not become active")
        XCTAssertEqual(state.helperState, .failed(message: "Lid-close prevention did not become active"))
    }
}
