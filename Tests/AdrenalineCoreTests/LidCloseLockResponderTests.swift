import Combine
import XCTest
@testable import AdrenalineCore

@MainActor
private final class FakeLidStateMonitor: LidStateMonitoring {
    var onLidStateChange: (@MainActor (LidState) -> Void)?
    private(set) var isMonitoring = false
    var currentLidState: LidState?

    func start() throws { isMonitoring = true }
    func stop() { isMonitoring = false }
    func emit(_ lidState: LidState) {
        currentLidState = lidState
        onLidStateChange?(lidState)
    }
}

@MainActor
private final class FakeScreenLocker: ScreenLocking {
    private(set) var lockCallCount = 0
    var lockError: Error?

    func lock() throws {
        lockCallCount += 1
        if let lockError { throw lockError }
    }
}

@MainActor
private final class FakePreferencesStore: PreferencesProviding {
    @Published var preventDisplaySleep: Bool = true
    @Published var preventLidCloseSleep: Bool = false
    @Published var playLidEventSounds: Bool = true
    @Published var lidClosePreventionConfirmed: Bool = false
    var wasActive: Bool = false

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

@MainActor
private final class FakeLockPolicyReader: MacOSLockPolicyReading {
    private(set) var readCallCount = 0
    var policy = MacOSLockPolicy(requiresPassword: true)
    var error: Error?

    func currentPolicy() throws -> MacOSLockPolicy {
        readCallCount += 1
        if let error { throw error }
        return policy
    }
}

private struct TestError: Error {}

@MainActor
final class LidCloseLockResponderTests: XCTestCase {
    private func makeResponder(
        isActive: Bool,
        preventDisplaySleep: Bool,
        preventLid: Bool,
        policy: MacOSLockPolicy = MacOSLockPolicy(requiresPassword: true)
    ) -> (
        state: AppState,
        monitor: FakeLidStateMonitor,
        locker: FakeScreenLocker,
        prefs: FakePreferencesStore,
        policyReader: FakeLockPolicyReader,
        responder: LidCloseLockResponder
    ) {
        let state = AppState(isActive: isActive)
        let monitor = FakeLidStateMonitor()
        let locker = FakeScreenLocker()
        let prefs = FakePreferencesStore()
        prefs.preventDisplaySleep = preventDisplaySleep
        prefs.preventLidCloseSleep = preventLid
        let policyReader = FakeLockPolicyReader()
        policyReader.policy = policy
        let responder = LidCloseLockResponder(
            state: state,
            monitor: monitor,
            screenLocker: locker,
            preferences: prefs,
            policyReader: policyReader
        )
        return (state, monitor, locker, prefs, policyReader, responder)
    }

    func testInactiveStateDoesNotReadPolicyOrLock() {
        let setup = makeResponder(isActive: false, preventDisplaySleep: false, preventLid: false)
        setup.monitor.emit(.closed)

        XCTAssertEqual(setup.policyReader.readCallCount, 0)
        XCTAssertEqual(setup.locker.lockCallCount, 0)
        _ = setup.responder
    }

    func testPreventDisplaySleepOnDoesNotReadPolicyOrLock() {
        let setup = makeResponder(isActive: true, preventDisplaySleep: true, preventLid: true)
        setup.monitor.emit(.closed)

        XCTAssertEqual(setup.policyReader.readCallCount, 0)
        XCTAssertEqual(setup.locker.lockCallCount, 0)
        _ = setup.responder
    }

    func testRequirePasswordEnabledLocksImmediatelyWhenLidClosePreventionIsOff() {
        let setup = makeResponder(isActive: true, preventDisplaySleep: false, preventLid: false)
        setup.monitor.emit(.closed)

        XCTAssertEqual(setup.policyReader.readCallCount, 1)
        XCTAssertEqual(setup.locker.lockCallCount, 1)
        _ = setup.responder
    }

    func testRequirePasswordEnabledLocksImmediatelyWhenLidClosePreventionIsOn() {
        let setup = makeResponder(isActive: true, preventDisplaySleep: false, preventLid: true)
        setup.monitor.emit(.closed)

        XCTAssertEqual(setup.policyReader.readCallCount, 1)
        XCTAssertEqual(setup.locker.lockCallCount, 1)
        _ = setup.responder
    }

    func testRequirePasswordDisabledDoesNotLock() {
        let setup = makeResponder(
            isActive: true,
            preventDisplaySleep: false,
            preventLid: false,
            policy: MacOSLockPolicy(requiresPassword: false)
        )

        setup.monitor.emit(.closed)

        XCTAssertEqual(setup.policyReader.readCallCount, 1)
        XCTAssertEqual(setup.locker.lockCallCount, 0)
        _ = setup.responder
    }

    func testPolicyReadErrorDoesNotLockOrMutateState() {
        let setup = makeResponder(isActive: true, preventDisplaySleep: false, preventLid: false)
        setup.policyReader.error = TestError()

        setup.monitor.emit(.closed)

        XCTAssertEqual(setup.policyReader.readCallCount, 1)
        XCTAssertEqual(setup.locker.lockCallCount, 0)
        XCTAssertTrue(setup.state.isActive)
        XCTAssertNil(setup.state.lastErrorMessage)
        _ = setup.responder
    }

    func testLockerThrowingDoesNotCrashOrMutateState() {
        let setup = makeResponder(isActive: true, preventDisplaySleep: false, preventLid: false)
        setup.locker.lockError = TestError()

        setup.monitor.emit(.closed)

        XCTAssertEqual(setup.locker.lockCallCount, 1)
        XCTAssertTrue(setup.state.isActive)
        XCTAssertNil(setup.state.lastErrorMessage)
        _ = setup.responder
    }

    func testExistingLidStateCallbackIsPreservedBeforeResponderLocks() {
        let state = AppState(isActive: true)
        let monitor = FakeLidStateMonitor()
        let locker = FakeScreenLocker()
        let prefs = FakePreferencesStore()
        prefs.preventDisplaySleep = false
        prefs.preventLidCloseSleep = false
        let policyReader = FakeLockPolicyReader()
        var forwardedStates: [LidState] = []
        monitor.onLidStateChange = { forwardedStates.append($0) }
        let responder = LidCloseLockResponder(
            state: state,
            monitor: monitor,
            screenLocker: locker,
            preferences: prefs,
            policyReader: policyReader
        )

        monitor.emit(.closed)

        XCTAssertEqual(forwardedStates, [.closed])
        XCTAssertEqual(policyReader.readCallCount, 1)
        XCTAssertEqual(locker.lockCallCount, 1)
        _ = responder
    }

    func testLidOpenDoesNotReadPolicyOrLock() {
        let setup = makeResponder(isActive: true, preventDisplaySleep: false, preventLid: false)

        setup.monitor.emit(.open)

        XCTAssertEqual(setup.policyReader.readCallCount, 0)
        XCTAssertEqual(setup.locker.lockCallCount, 0)
        _ = setup.responder
    }
}
