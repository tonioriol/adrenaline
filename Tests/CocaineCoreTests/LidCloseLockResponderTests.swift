import Combine
import XCTest
@testable import CocaineCore

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
    @Published var lockScreenOnLidClose: Bool = true
    @Published var playLidEventSounds: Bool = true
    @Published var lidClosePreventionConfirmed: Bool = false

    var preventDisplaySleepPublisher: AnyPublisher<Bool, Never> { $preventDisplaySleep.eraseToAnyPublisher() }
    var preventLidCloseSleepPublisher: AnyPublisher<Bool, Never> { $preventLidCloseSleep.eraseToAnyPublisher() }
    var lockScreenOnLidClosePublisher: AnyPublisher<Bool, Never> { $lockScreenOnLidClose.eraseToAnyPublisher() }
    var playLidEventSoundsPublisher: AnyPublisher<Bool, Never> { $playLidEventSounds.eraseToAnyPublisher() }

    func snapshot() -> PreferencesSnapshot {
        PreferencesSnapshot(
            preventDisplaySleep: preventDisplaySleep,
            preventLidCloseSleep: preventLidCloseSleep,
            lockScreenOnLidClose: lockScreenOnLidClose,
            playLidEventSounds: playLidEventSounds
        )
    }
}

@MainActor
private final class FakeLockPolicyReader: MacOSLockPolicyReading {
    private(set) var readCallCount = 0
    var policy = MacOSLockPolicy(requiresPassword: true, displaySleepDelay: 60, passwordDelay: 0)
    var error: Error?

    func currentPolicy() throws -> MacOSLockPolicy {
        readCallCount += 1
        if let error { throw error }
        return policy
    }
}

@MainActor
private final class FakeLockScheduler: LidCloseLockScheduling {
    private(set) var scheduledDelays: [TimeInterval] = []
    private(set) var cancellables: [FakeLockCancellable] = []
    private var pendingOperation: (@MainActor @Sendable () -> Void)?

    func schedule(after delay: TimeInterval, operation: @escaping @MainActor @Sendable () -> Void) -> LidCloseLockCancellable {
        scheduledDelays.append(delay)
        pendingOperation = operation
        let cancellable = FakeLockCancellable()
        cancellables.append(cancellable)
        return cancellable
    }

    func fire() {
        pendingOperation?()
        pendingOperation = nil
    }
}

@MainActor
private final class FakeLockCancellable: LidCloseLockCancellable {
    private(set) var cancelCallCount = 0

    func cancel() {
        cancelCallCount += 1
    }
}

private struct TestError: Error {}

@MainActor
final class LidCloseLockResponderTests: XCTestCase {
    private func makeResponder(
        isActive: Bool,
        preventDisplaySleep: Bool,
        preventLid: Bool,
        policy: MacOSLockPolicy = MacOSLockPolicy(requiresPassword: true, displaySleepDelay: 60, passwordDelay: 0)
    ) -> (
        monitor: FakeLidStateMonitor,
        locker: FakeScreenLocker,
        prefs: FakePreferencesStore,
        policyReader: FakeLockPolicyReader,
        scheduler: FakeLockScheduler,
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
        let scheduler = FakeLockScheduler()
        let responder = LidCloseLockResponder(
            state: state,
            monitor: monitor,
            screenLocker: locker,
            preferences: prefs,
            policyReader: policyReader,
            scheduler: scheduler
        )
        return (monitor, locker, prefs, policyReader, scheduler, responder)
    }

    func testInactiveStateDoesNotReadPolicyOrScheduleLock() {
        let setup = makeResponder(isActive: false, preventDisplaySleep: false, preventLid: true)
        setup.monitor.emit(.closed)
        XCTAssertEqual(setup.policyReader.readCallCount, 0)
        XCTAssertEqual(setup.scheduler.scheduledDelays, [])
        XCTAssertEqual(setup.locker.lockCallCount, 0)
        _ = setup.responder
    }

    func testPreventLidCloseOffDoesNotReadPolicyOrScheduleLock() {
        let setup = makeResponder(isActive: true, preventDisplaySleep: false, preventLid: false)
        setup.monitor.emit(.closed)
        XCTAssertEqual(setup.policyReader.readCallCount, 0)
        XCTAssertEqual(setup.scheduler.scheduledDelays, [])
        XCTAssertEqual(setup.locker.lockCallCount, 0)
        _ = setup.responder
    }

    func testPreventDisplaySleepOnDoesNotReadPolicyOrScheduleLock() {
        let setup = makeResponder(isActive: true, preventDisplaySleep: true, preventLid: true)
        setup.monitor.emit(.closed)
        XCTAssertEqual(setup.policyReader.readCallCount, 0)
        XCTAssertEqual(setup.scheduler.scheduledDelays, [])
        XCTAssertEqual(setup.locker.lockCallCount, 0)
        _ = setup.responder
    }

    func testRequirePasswordDisabledDoesNotScheduleLock() {
        let setup = makeResponder(
            isActive: true,
            preventDisplaySleep: false,
            preventLid: true,
            policy: MacOSLockPolicy(requiresPassword: false, displaySleepDelay: 60, passwordDelay: 0)
        )
        setup.monitor.emit(.closed)
        XCTAssertEqual(setup.policyReader.readCallCount, 1)
        XCTAssertEqual(setup.scheduler.scheduledDelays, [])
        XCTAssertEqual(setup.locker.lockCallCount, 0)
        _ = setup.responder
    }

    func testRequirePasswordEnabledSchedulesLockAfterPolicyDelay() {
        let setup = makeResponder(
            isActive: true,
            preventDisplaySleep: false,
            preventLid: true,
            policy: MacOSLockPolicy(requiresPassword: true, displaySleepDelay: 300, passwordDelay: 5)
        )

        setup.monitor.emit(.closed)

        XCTAssertEqual(setup.policyReader.readCallCount, 1)
        XCTAssertEqual(setup.scheduler.scheduledDelays, [305])
        XCTAssertEqual(setup.locker.lockCallCount, 0)

        setup.scheduler.fire()

        XCTAssertEqual(setup.locker.lockCallCount, 1)
        _ = setup.responder
    }

    func testLidOpenBeforeDelayCancelsPendingLock() {
        let setup = makeResponder(isActive: true, preventDisplaySleep: false, preventLid: true)
        setup.monitor.emit(.closed)
        setup.monitor.emit(.open)
        setup.scheduler.fire()

        XCTAssertEqual(setup.scheduler.cancellables.first?.cancelCallCount, 1)
        XCTAssertEqual(setup.locker.lockCallCount, 0)
        _ = setup.responder
    }

    func testInactiveBeforeDelayPreventsLock() {
        let state = AppState(isActive: true)
        let monitor = FakeLidStateMonitor()
        let locker = FakeScreenLocker()
        let prefs = FakePreferencesStore()
        prefs.preventDisplaySleep = false
        prefs.preventLidCloseSleep = true
        let policyReader = FakeLockPolicyReader()
        let scheduler = FakeLockScheduler()
        let responder = LidCloseLockResponder(
            state: state,
            monitor: monitor,
            screenLocker: locker,
            preferences: prefs,
            policyReader: policyReader,
            scheduler: scheduler
        )

        monitor.emit(.closed)
        state.setActive(false)
        scheduler.fire()

        XCTAssertEqual(locker.lockCallCount, 0)
        _ = responder
    }

    func testPreventDisplaySleepEnabledBeforeDelayPreventsLock() {
        let setup = makeResponder(isActive: true, preventDisplaySleep: false, preventLid: true)
        setup.monitor.emit(.closed)
        setup.prefs.preventDisplaySleep = true
        setup.scheduler.fire()

        XCTAssertEqual(setup.locker.lockCallCount, 0)
        _ = setup.responder
    }

    func testPreventLidCloseDisabledBeforeDelayPreventsLock() {
        let setup = makeResponder(isActive: true, preventDisplaySleep: false, preventLid: true)
        setup.monitor.emit(.closed)
        setup.prefs.preventLidCloseSleep = false
        setup.scheduler.fire()

        XCTAssertEqual(setup.locker.lockCallCount, 0)
        _ = setup.responder
    }

    func testPolicyReadErrorDoesNotScheduleOrLock() {
        let setup = makeResponder(isActive: true, preventDisplaySleep: false, preventLid: true)
        setup.policyReader.error = TestError()
        setup.monitor.emit(.closed)

        XCTAssertEqual(setup.policyReader.readCallCount, 1)
        XCTAssertEqual(setup.scheduler.scheduledDelays, [])
        XCTAssertEqual(setup.locker.lockCallCount, 0)
        _ = setup.responder
    }

    func testLockerThrowingDoesNotCrashOrMutateState() {
        let state = AppState(isActive: true)
        let monitor = FakeLidStateMonitor()
        let locker = FakeScreenLocker()
        locker.lockError = TestError()
        let prefs = FakePreferencesStore()
        prefs.preventDisplaySleep = false
        prefs.preventLidCloseSleep = true
        let policyReader = FakeLockPolicyReader()
        let scheduler = FakeLockScheduler()
        let responder = LidCloseLockResponder(
            state: state,
            monitor: monitor,
            screenLocker: locker,
            preferences: prefs,
            policyReader: policyReader,
            scheduler: scheduler
        )

        monitor.emit(.closed)
        scheduler.fire()

        XCTAssertEqual(locker.lockCallCount, 1)
        XCTAssertTrue(state.isActive)
        XCTAssertNil(state.lastErrorMessage)
        _ = responder
    }

    func testExistingLidStateCallbackIsPreservedBeforeResponderSchedules() {
        let state = AppState(isActive: true)
        let monitor = FakeLidStateMonitor()
        let locker = FakeScreenLocker()
        let prefs = FakePreferencesStore()
        prefs.preventDisplaySleep = false
        prefs.preventLidCloseSleep = true
        let policyReader = FakeLockPolicyReader()
        let scheduler = FakeLockScheduler()
        var forwardedStates: [LidState] = []
        monitor.onLidStateChange = { forwardedStates.append($0) }
        let responder = LidCloseLockResponder(
            state: state,
            monitor: monitor,
            screenLocker: locker,
            preferences: prefs,
            policyReader: policyReader,
            scheduler: scheduler
        )

        monitor.emit(.closed)

        XCTAssertEqual(forwardedStates, [.closed])
        XCTAssertEqual(scheduler.scheduledDelays, [60])
        _ = responder
    }
}
