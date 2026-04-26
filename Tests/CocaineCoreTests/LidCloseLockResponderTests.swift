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
    func emit(_ lidState: LidState) { onLidStateChange?(lidState) }
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

private struct TestError: Error {}

@MainActor
final class LidCloseLockResponderTests: XCTestCase {
    private func makeResponder(
        isActive: Bool,
        preventDisplaySleep: Bool,
        preventLid: Bool,
        lockOnClose: Bool = true)
        -> (FakeLidStateMonitor, FakeScreenLocker, LidCloseLockResponder)
    {
        let state = AppState(isActive: isActive)
        let monitor = FakeLidStateMonitor()
        let locker = FakeScreenLocker()
        let prefs = FakePreferencesStore()
        prefs.preventDisplaySleep = preventDisplaySleep
        prefs.preventLidCloseSleep = preventLid
        prefs.lockScreenOnLidClose = lockOnClose
        let responder = LidCloseLockResponder(state: state, monitor: monitor, screenLocker: locker, preferences: prefs)
        return (monitor, locker, responder)
    }

    func testInactiveStateDoesNotLock() {
        let (monitor, locker, responder) = makeResponder(isActive: false, preventDisplaySleep: false, preventLid: true)
        monitor.emit(.closed)
        XCTAssertEqual(locker.lockCallCount, 0)
        _ = responder
    }

    func testPreventLidCloseOffDoesNotLock() {
        let (monitor, locker, responder) = makeResponder(isActive: true, preventDisplaySleep: false, preventLid: false)
        monitor.emit(.closed)
        XCTAssertEqual(locker.lockCallCount, 0)
        _ = responder
    }

    func testPreventDisplaySleepOnDoesNotLock() {
        let (monitor, locker, responder) = makeResponder(isActive: true, preventDisplaySleep: true, preventLid: true)
        monitor.emit(.closed)
        XCTAssertEqual(locker.lockCallCount, 0)
        _ = responder
    }

    func testLockScreenOnLidCloseOffDoesNotLock() {
        let (monitor, locker, responder) = makeResponder(
            isActive: true,
            preventDisplaySleep: false,
            preventLid: true,
            lockOnClose: false)
        monitor.emit(.closed)
        XCTAssertEqual(locker.lockCallCount, 0)
        _ = responder
    }

    func testPreventDisplaySleepOffAndPreventLidCloseOnLocksOnceOnClose() {
        let (monitor, locker, responder) = makeResponder(isActive: true, preventDisplaySleep: false, preventLid: true)
        monitor.emit(.closed)
        XCTAssertEqual(locker.lockCallCount, 1)
        _ = responder
    }

    func testLidOpenNeverLocks() {
        let (monitor, locker, responder) = makeResponder(isActive: true, preventDisplaySleep: false, preventLid: true)
        monitor.emit(.open)
        monitor.emit(.open)
        XCTAssertEqual(locker.lockCallCount, 0)
        _ = responder
    }

    func testLockerThrowingDoesNotCrash() {
        let state = AppState(isActive: true)
        let monitor = FakeLidStateMonitor()
        let locker = FakeScreenLocker()
        locker.lockError = TestError()
        let prefs = FakePreferencesStore()
        prefs.preventDisplaySleep = false
        prefs.preventLidCloseSleep = true
        let responder = LidCloseLockResponder(state: state, monitor: monitor, screenLocker: locker, preferences: prefs)

        monitor.emit(.closed)

        XCTAssertEqual(locker.lockCallCount, 1)
        XCTAssertTrue(state.isActive)
        XCTAssertNil(state.lastErrorMessage)
        _ = responder
    }

    func testExistingLidStateCallbackIsPreservedBeforeResponderLocks() {
        let state = AppState(isActive: true)
        let monitor = FakeLidStateMonitor()
        let locker = FakeScreenLocker()
        let prefs = FakePreferencesStore()
        prefs.preventDisplaySleep = false
        prefs.preventLidCloseSleep = true
        var forwardedStates: [LidState] = []
        monitor.onLidStateChange = { forwardedStates.append($0) }
        let responder = LidCloseLockResponder(state: state, monitor: monitor, screenLocker: locker, preferences: prefs)

        monitor.emit(.closed)

        XCTAssertEqual(forwardedStates, [.closed])
        XCTAssertEqual(locker.lockCallCount, 1)
        _ = responder
    }
}
