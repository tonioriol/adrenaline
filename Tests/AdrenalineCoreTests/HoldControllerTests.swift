import XCTest
@testable import AdrenalineCore

/// Coordinator stand-in that transitions synchronously, or defers when `deferTransitions` is set.
final class FakeHoldCoordinator: HoldActivating {
    let state: AppState
    var onTransitionEnd: (() -> Void)?
    var turnOnCount = 0
    var turnOffCount = 0
    var failTurnOn = false
    var deferTransitions = false
    private var pending: (() -> Void)?

    init(state: AppState) { self.state = state }

    @discardableResult func turnOn() -> Bool {
        guard pending == nil else { return false }
        turnOnCount += 1
        run { [self] in
            if failTurnOn { state.recordError("boom") } else { state.setActive(true) }
        }
        return true
    }

    @discardableResult func turnOff() -> Bool {
        guard pending == nil else { return false }
        turnOffCount += 1
        run { [self] in state.setActive(false) }
        return true
    }

    func finishPending() {
        let work = pending
        pending = nil
        work?()
    }

    private func run(_ work: @escaping () -> Void) {
        let finish = { [self] in
            work()
            onTransitionEnd?()
        }
        if deferTransitions { pending = finish } else { finish() }
    }
}

final class HoldControllerTests: XCTestCase {
    private var state: AppState!
    private var coordinator: FakeHoldCoordinator!
    private var holds: HoldController!

    override func setUp() {
        state = AppState()
        coordinator = FakeHoldCoordinator(state: state)
        holds = HoldController(state: state, coordinator: coordinator, mode: .auto)
    }

    func testAutoActivatesForFirstHoldAndDeactivatesAfterLastRelease() throws {
        XCTAssertFalse(state.isActive)
        let a = try XCTUnwrap(holds.acquire(reason: "a", pid: 42))
        let b = try XCTUnwrap(holds.acquire(reason: "b", pid: nil))
        XCTAssertTrue(state.isActive)
        XCTAssertTrue(holds.isAutoHeld)
        XCTAssertEqual(coordinator.turnOnCount, 1)

        holds.release(a)
        XCTAssertTrue(state.isActive)
        holds.release(b)
        XCTAssertFalse(state.isActive)
        XCTAssertFalse(holds.isAutoHeld)
        XCTAssertEqual(coordinator.turnOffCount, 1)
    }

    func testOffClearsAndRefusesHoldsEvenDuringTurnOn() throws {
        coordinator.deferTransitions = true
        let id = try XCTUnwrap(holds.acquire(reason: "a", pid: 42))
        holds.setMode(.off)
        XCTAssertNil(holds.acquire(reason: "b", pid: nil))
        XCTAssertTrue(holds.holds.isEmpty)
        coordinator.finishPending()
        coordinator.finishPending()
        XCTAssertFalse(state.isActive)
        holds.release(id)
        holds.setMode(.auto)
        XCTAssertFalse(state.isActive)
    }

    func testOnAtLaunchAndReleaseDoesNotDeactivate() throws {
        holds = HoldController(state: state, coordinator: coordinator, mode: .on)
        XCTAssertTrue(state.isActive)
        let id = try XCTUnwrap(holds.acquire(reason: "a", pid: 42))
        XCTAssertFalse(holds.isHoldDriven)
        holds.release(id)
        XCTAssertTrue(state.isActive)
        holds.setMode(.auto)
        XCTAssertFalse(state.isActive)
    }

    func testChangingBetweenAutoHeldAndOnDoesNotCyclePower() throws {
        let id = try XCTUnwrap(holds.acquire(reason: "a", pid: 42))
        holds.setMode(.on)
        XCTAssertFalse(holds.isAutoHeld)
        holds.setMode(.auto)
        XCTAssertTrue(holds.isAutoHeld)
        XCTAssertEqual(coordinator.turnOnCount, 1)
        XCTAssertEqual(coordinator.turnOffCount, 0)
        holds.release(id)
        XCTAssertFalse(state.isActive)
    }

    func testHoldNotificationsExposeChangesWhileActivationIsUnchanged() throws {
        holds.setMode(.on)
        let notified = expectation(description: "add, replace, remove")
        notified.expectedFulfillmentCount = 3
        let observer = NotificationCenter.default.addObserver(forName: .holdStateDidChange, object: holds, queue: nil) { _ in
            notified.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        let a = try XCTUnwrap(holds.acquire(reason: "first", pid: 41))
        let b = try XCTUnwrap(holds.acquire(reason: "replacement", pid: 42, replacing: a))
        XCTAssertEqual(holds.holds, [Hold(id: b, reason: "replacement", pid: 42)])
        holds.release(b)
        wait(for: [notified], timeout: 0.2)
        XCTAssertTrue(state.isActive)
    }

    func testFailedTurnOnIsNotRetriedInALoop() {
        coordinator.failTurnOn = true
        holds.acquire(reason: nil, pid: nil)
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(coordinator.turnOnCount, 1)
        XCTAssertFalse(holds.isHoldDriven)
    }

    func testReleaseDuringOwnTurnOnTurnsOffAfterwards() throws {
        coordinator.deferTransitions = true
        let id = try XCTUnwrap(holds.acquire(reason: nil, pid: nil))
        holds.release(id)
        coordinator.finishPending()
        coordinator.finishPending()
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(coordinator.turnOffCount, 1)
    }
}
