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

    /// Simulates the user clicking the menu bar icon.
    func userToggle() {
        if state.isActive { _ = turnOff() } else { _ = turnOn() }
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
        holds = HoldController(state: state, coordinator: coordinator)
    }

    func testFirstHoldTurnsOnAndLastReleaseTurnsOff() {
        let a = holds.acquire(reason: "a", pid: nil)
        let b = holds.acquire(reason: "b", pid: nil)
        XCTAssertTrue(state.isActive)
        XCTAssertEqual(coordinator.turnOnCount, 1)
        XCTAssertTrue(holds.isHoldDriven)

        holds.release(a)
        XCTAssertTrue(state.isActive)
        holds.release(b)
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(coordinator.turnOffCount, 1)
    }

    func testReleasingDoesNotTurnOffWhenUserHadItOn() {
        coordinator.userToggle()
        let id = holds.acquire(reason: nil, pid: nil)
        XCTAssertFalse(holds.isHoldDriven)
        holds.release(id)
        XCTAssertTrue(state.isActive)
        XCTAssertEqual(coordinator.turnOffCount, 0)
    }

    func testUserTurningOffYieldsUntilNextHold() {
        _ = holds.acquire(reason: nil, pid: nil)
        coordinator.userToggle()
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(coordinator.turnOnCount, 1, "must not fight the user")

        _ = holds.acquire(reason: nil, pid: nil)
        XCTAssertTrue(state.isActive)
        XCTAssertEqual(coordinator.turnOnCount, 2)
    }

    func testUserTakingOverKeepsItOnAfterRelease() {
        let id = holds.acquire(reason: nil, pid: nil)
        coordinator.userToggle() // off
        coordinator.userToggle() // user turns it back on themselves
        holds.release(id)
        XCTAssertTrue(state.isActive)
    }

    func testFailedTurnOnIsNotRetriedInALoop() {
        coordinator.failTurnOn = true
        _ = holds.acquire(reason: nil, pid: nil)
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(coordinator.turnOnCount, 1)
        XCTAssertFalse(holds.isHoldDriven)
    }

    func testHoldArrivingDuringTransitionIsAppliedAfterIt() {
        coordinator.deferTransitions = true
        coordinator.userToggle() // user turn-on in flight
        let id = holds.acquire(reason: nil, pid: nil)
        coordinator.finishPending()
        XCTAssertTrue(state.isActive)
        XCTAssertFalse(holds.isHoldDriven, "user started this activation")

        holds.release(id)
        XCTAssertEqual(coordinator.turnOffCount, 0)
    }

    func testReleaseDuringOwnTurnOnTurnsOffAfterwards() {
        coordinator.deferTransitions = true
        let id = holds.acquire(reason: nil, pid: nil)
        holds.release(id)
        coordinator.finishPending() // turn-on lands, then reconcile turns off
        coordinator.finishPending()
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(coordinator.turnOffCount, 1)
    }
}
