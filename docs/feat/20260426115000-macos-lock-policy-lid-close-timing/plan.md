# macOS Lid-Close Lock Timing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Insomnia mirror macOS lock timing when lid-close sleep prevention keeps the Mac awake: skip locking when Require Password is disabled, otherwise lock after the active display-off timer plus password delay.

**Architecture:** Add a small `InsomniaCore` policy reader for macOS lock/display settings, then refactor `LidCloseLockResponder` to schedule a cancellable delayed lock instead of calling the locker immediately. Keep menu behavior unchanged and update README to describe the macOS-matching behavior.

**Tech Stack:** Swift 5.9, SwiftPM, AppKit wiring, Foundation `UserDefaults`, property-list reading, IOKit power-source APIs, XCTest, existing `ScreenLocker` / `LidStateMonitor` abstractions.

---

## File Structure

**Create:**

- `Sources/InsomniaCore/MacOSLockPolicyReader.swift` — `MacOSLockPolicy`, `MacOSPowerSource`, `MacOSLockPolicyReading`, and concrete `MacOSLockPolicyReader` that reads `com.apple.screensaver`, `/Library/Preferences/com.apple.PowerManagement.plist`, and current power source.
- `Sources/InsomniaCore/LidCloseLockScheduler.swift` — small scheduling abstraction plus production `Task`-backed scheduler so responder tests can fire delayed locks without waiting real minutes.
- `Tests/InsomniaCoreTests/MacOSLockPolicyReaderTests.swift` — pure tests for password policy parsing, display timer selection, power-source behavior, and unreadable settings behavior.

**Modify:**

- `Sources/InsomniaCore/LidCloseLockResponder.swift` — inject policy reader and scheduler; replace immediate lock with delayed/cancellable lock scheduling and final gate rechecks.
- `Sources/Insomnia/AppDelegate.swift` — construct `MacOSLockPolicyReader` and pass it into `LidCloseLockResponder`.
- `Tests/InsomniaCoreTests/LidCloseLockResponderTests.swift` — replace immediate-lock expectations with delayed scheduling, cancellation, and recheck coverage.
- `README.md` — describe that lid-close locking follows macOS Require Password and display-off timing.
- `docs/feat/20260426115000-macos-lock-policy-lid-close-timing/context.md` — update plan link, FILES, cursor, and log.

---

### Task 1: Add macOS lock policy reader

**Files:**
- Create: `Sources/InsomniaCore/MacOSLockPolicyReader.swift`
- Create: `Tests/InsomniaCoreTests/MacOSLockPolicyReaderTests.swift`

- [x] **Step 1: Write failing policy reader tests**

Create `Tests/InsomniaCoreTests/MacOSLockPolicyReaderTests.swift` with this content:

```swift
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
```

- [x] **Step 2: Run the policy reader tests to verify they fail**

Run:

```bash
swift test --filter MacOSLockPolicyReaderTests 2>&1 | tail -40
```

Expected: FAIL with compiler errors like `cannot find type 'MacOSPowerSource' in scope` and `cannot find 'MacOSLockPolicyReader' in scope`.

- [x] **Step 3: Add the policy reader implementation**

Create `Sources/InsomniaCore/MacOSLockPolicyReader.swift` with this content:

```swift
import Foundation
import IOKit.ps

public enum MacOSPowerSource: Equatable, Sendable {
    case battery
    case ac
}

public struct MacOSLockPolicy: Equatable, Sendable {
    public var requiresPassword: Bool
    public var displaySleepDelay: TimeInterval
    public var passwordDelay: TimeInterval

    public init(requiresPassword: Bool, displaySleepDelay: TimeInterval, passwordDelay: TimeInterval) {
        self.requiresPassword = requiresPassword
        self.displaySleepDelay = max(0, displaySleepDelay)
        self.passwordDelay = max(0, passwordDelay)
    }

    public var lockDelay: TimeInterval? {
        guard requiresPassword, displaySleepDelay > 0 else { return nil }
        return displaySleepDelay + passwordDelay
    }
}

public enum MacOSLockPolicyReaderError: Error, LocalizedError, Equatable {
    case powerSettingsUnreadable
    case displaySleepTimerUnavailable

    public var errorDescription: String? {
        switch self {
        case .powerSettingsUnreadable:
            return "Could not read macOS power settings"
        case .displaySleepTimerUnavailable:
            return "Could not read macOS display sleep timer"
        }
    }
}

@MainActor
public protocol MacOSLockPolicyReading: AnyObject {
    func currentPolicy() throws -> MacOSLockPolicy
}

@MainActor
public final class MacOSLockPolicyReader: MacOSLockPolicyReading {
    private static let screenSaverSuiteName = "com.apple.screensaver"
    private static let defaultPowerSettingsPath = "/Library/Preferences/com.apple.PowerManagement.plist"
    private static let batteryPowerKey = "Battery Power"
    private static let acPowerKey = "AC Power"
    private static let upsPowerKey = "UPS Power"
    private static let displaySleepTimerKey = "Display Sleep Timer"
    private static let askForPasswordKey = "askForPassword"
    private static let askForPasswordDelayKey = "askForPasswordDelay"

    private let screenSaverDefaults: UserDefaults
    private let powerSettingsURL: URL
    private let powerSourceProvider: () -> MacOSPowerSource?

    public convenience init() {
        self.init(
            screenSaverDefaults: UserDefaults(suiteName: Self.screenSaverSuiteName) ?? .standard,
            powerSettingsURL: URL(fileURLWithPath: Self.defaultPowerSettingsPath),
            powerSourceProvider: Self.currentPowerSource
        )
    }

    public init(
        screenSaverDefaults: UserDefaults,
        powerSettingsURL: URL,
        powerSourceProvider: @escaping () -> MacOSPowerSource?
    ) {
        self.screenSaverDefaults = screenSaverDefaults
        self.powerSettingsURL = powerSettingsURL
        self.powerSourceProvider = powerSourceProvider
    }

    public func currentPolicy() throws -> MacOSLockPolicy {
        let requiresPassword = Self.boolValue(screenSaverDefaults.object(forKey: Self.askForPasswordKey))
        let passwordDelay = max(0, Self.timeIntervalValue(screenSaverDefaults.object(forKey: Self.askForPasswordDelayKey)) ?? 0)
        let displaySleepDelay = try currentDisplaySleepDelay()

        return MacOSLockPolicy(
            requiresPassword: requiresPassword,
            displaySleepDelay: displaySleepDelay,
            passwordDelay: passwordDelay
        )
    }

    private func currentDisplaySleepDelay() throws -> TimeInterval {
        let settings = try readPowerSettings()
        let source = powerSourceProvider()
        let timerMinutes = try displaySleepTimerMinutes(in: settings, preferredSource: source)
        return max(0, timerMinutes) * 60
    }

    private func readPowerSettings() throws -> [String: Any] {
        do {
            let data = try Data(contentsOf: powerSettingsURL)
            guard let dictionary = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any] else {
                throw MacOSLockPolicyReaderError.powerSettingsUnreadable
            }
            return dictionary
        } catch let error as MacOSLockPolicyReaderError {
            throw error
        } catch {
            throw MacOSLockPolicyReaderError.powerSettingsUnreadable
        }
    }

    private func displaySleepTimerMinutes(in settings: [String: Any], preferredSource: MacOSPowerSource?) throws -> TimeInterval {
        let preferredKeys: [String]
        switch preferredSource {
        case .battery:
            preferredKeys = [Self.batteryPowerKey, Self.acPowerKey]
        case .ac:
            preferredKeys = [Self.acPowerKey, Self.batteryPowerKey]
        case nil:
            preferredKeys = [Self.batteryPowerKey, Self.acPowerKey]
        }

        for sourceKey in preferredKeys {
            guard let sourceSettings = settings[sourceKey] as? [String: Any] else { continue }
            if let minutes = Self.timeIntervalValue(sourceSettings[Self.displaySleepTimerKey]) {
                return minutes
            }
        }

        throw MacOSLockPolicyReaderError.displaySleepTimerUnavailable
    }

    private static func currentPowerSource() -> MacOSPowerSource? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let unmanagedSource = IOPSGetProvidingPowerSourceType(snapshot) else {
            return nil
        }
        let rawSource = unmanagedSource.takeUnretainedValue() as String

        switch rawSource {
        case batteryPowerKey:
            return .battery
        case acPowerKey, upsPowerKey:
            return .ac
        default:
            return nil
        }
    }

    private static func boolValue(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.intValue != 0 }
        if let string = value as? String {
            return string == "1" || string.lowercased() == "true" || string.lowercased() == "yes"
        }
        return false
    }

    private static func timeIntervalValue(_ value: Any?) -> TimeInterval? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let timeInterval = value as? TimeInterval { return timeInterval }
        if let int = value as? Int { return TimeInterval(int) }
        if let double = value as? Double { return double }
        if let string = value as? String { return TimeInterval(string) }
        return nil
    }
}
```

- [x] **Step 4: Run the policy reader tests to verify they pass**

Run:

```bash
swift test --filter MacOSLockPolicyReaderTests 2>&1 | tail -40
```

Expected: PASS with all `MacOSLockPolicyReaderTests` tests passing.

- [x] **Step 5: Commit the policy reader**

Run:

```bash
git add Sources/InsomniaCore/MacOSLockPolicyReader.swift Tests/InsomniaCoreTests/MacOSLockPolicyReaderTests.swift
git commit -m "feat: read macos lock timing policy"
```

Expected: commit succeeds.

---

### Task 2: Add cancellable delayed lock scheduling to the responder

**Files:**
- Create: `Sources/InsomniaCore/LidCloseLockScheduler.swift`
- Modify: `Sources/InsomniaCore/LidCloseLockResponder.swift`
- Modify: `Tests/InsomniaCoreTests/LidCloseLockResponderTests.swift`

- [x] **Step 1: Replace responder tests with delayed-lock coverage**

Replace `Tests/InsomniaCoreTests/LidCloseLockResponderTests.swift` with this content:

```swift
import Combine
import XCTest
@testable import InsomniaCore

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
```

- [x] **Step 2: Run responder tests to verify they fail**

Run:

```bash
swift test --filter LidCloseLockResponderTests 2>&1 | tail -60
```

Expected: FAIL with compiler errors like `cannot find type 'LidCloseLockScheduling' in scope` and initializer argument label errors for `policyReader` / `scheduler`.

- [x] **Step 3: Add the scheduler abstraction**

Create `Sources/InsomniaCore/LidCloseLockScheduler.swift` with this content:

```swift
import Foundation

@MainActor
public protocol LidCloseLockCancellable: AnyObject {
    func cancel()
}

@MainActor
public protocol LidCloseLockScheduling: AnyObject {
    func schedule(after delay: TimeInterval, operation: @escaping @MainActor @Sendable () -> Void) -> LidCloseLockCancellable
}

@MainActor
public final class TaskLidCloseLockScheduler: LidCloseLockScheduling {
    public init() {}

    public func schedule(after delay: TimeInterval, operation: @escaping @MainActor @Sendable () -> Void) -> LidCloseLockCancellable {
        let clampedDelay = max(0, delay)
        let maxSeconds = Double(UInt64.max) / 1_000_000_000
        let nanoseconds = UInt64(min(clampedDelay, maxSeconds) * 1_000_000_000)

        let task = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            operation()
        }

        return TaskLidCloseLockCancellable(task: task)
    }
}

@MainActor
private final class TaskLidCloseLockCancellable: LidCloseLockCancellable {
    private let task: Task<Void, Never>

    init(task: Task<Void, Never>) {
        self.task = task
    }

    deinit {
        task.cancel()
    }

    func cancel() {
        task.cancel()
    }
}
```

- [x] **Step 4: Refactor `LidCloseLockResponder` to schedule delayed locks**

Replace `Sources/InsomniaCore/LidCloseLockResponder.swift` with this content:

```swift
import Foundation
import os.log

@MainActor
public final class LidCloseLockResponder {
    private static let log = OSLog(subsystem: "com.tonioriol.insomnia", category: "LidCloseLockResponder")

    private let state: AppState
    private let monitor: LidStateMonitoring
    private let screenLocker: ScreenLocking
    private let preferences: PreferencesProviding
    private let policyReader: MacOSLockPolicyReading
    private let scheduler: LidCloseLockScheduling
    private var pendingLock: LidCloseLockCancellable?

    public init(
        state: AppState,
        monitor: LidStateMonitoring,
        screenLocker: ScreenLocking,
        preferences: PreferencesProviding,
        policyReader: MacOSLockPolicyReading,
        scheduler: LidCloseLockScheduling = TaskLidCloseLockScheduler()
    ) {
        self.state = state
        self.monitor = monitor
        self.screenLocker = screenLocker
        self.preferences = preferences
        self.policyReader = policyReader
        self.scheduler = scheduler

        let existing = monitor.onLidStateChange
        monitor.onLidStateChange = { [weak self] lidState in
            existing?(lidState)
            self?.handle(lidState)
        }
    }

    deinit {
        pendingLock?.cancel()
    }

    private func handle(_ lidState: LidState) {
        switch lidState {
        case .open:
            cancelPendingLock()
        case .closed:
            scheduleLockIfNeeded()
        }
    }

    private func scheduleLockIfNeeded() {
        cancelPendingLock()

        guard shouldLockIfTimerFires else { return }

        do {
            let policy = try policyReader.currentPolicy()
            guard let delay = policy.lockDelay else { return }

            pendingLock = scheduler.schedule(after: delay) { [weak self] in
                self?.lockIfStillNeeded()
            }
        } catch {
            os_log(
                "Could not read macOS lock policy: %{public}s",
                log: Self.log,
                type: .error,
                error.localizedDescription
            )
        }
    }

    private func lockIfStillNeeded() {
        pendingLock = nil

        guard shouldLockIfTimerFires else { return }
        guard monitor.currentLidState == .closed else { return }

        do {
            try screenLocker.lock()
        } catch {
            os_log(
                "Screen lock failed: %{public}s",
                log: Self.log,
                type: .error,
                error.localizedDescription
            )
        }
    }

    private var shouldLockIfTimerFires: Bool {
        state.isActive && preferences.preventLidCloseSleep && !preferences.preventDisplaySleep
    }

    private func cancelPendingLock() {
        pendingLock?.cancel()
        pendingLock = nil
    }
}
```

- [x] **Step 5: Run responder tests to verify they pass**

Run:

```bash
swift test --filter LidCloseLockResponderTests 2>&1 | tail -60
```

Expected: PASS with all `LidCloseLockResponderTests` tests passing.

- [x] **Step 6: Commit delayed responder behavior**

Run:

```bash
git add Sources/InsomniaCore/LidCloseLockScheduler.swift Sources/InsomniaCore/LidCloseLockResponder.swift Tests/InsomniaCoreTests/LidCloseLockResponderTests.swift
git commit -m "feat: delay lid-close lock to match macos policy"
```

Expected: commit succeeds.

---

### Task 3: Wire the policy reader into the app and verify integration

**Files:**
- Modify: `Sources/Insomnia/AppDelegate.swift`

- [x] **Step 1: Run build to capture current integration failure**

Run:

```bash
swift build 2>&1 | tail -40
```

Expected: FAIL because `AppDelegate` still calls `LidCloseLockResponder` without the new `policyReader:` argument.

- [x] **Step 2: Wire the production policy reader**

In `Sources/Insomnia/AppDelegate.swift`, change the setup around `screenLocker` and `LidCloseLockResponder` to this exact shape:

```swift
        let lidStateMonitor = LidStateMonitor()
        let soundPlayer = SystemSoundPlayer()
        let screenLocker = LoginFrameworkScreenLocker()
        let lockPolicyReader = MacOSLockPolicyReader()

        let lidEventSoundController = LidEventSoundController(
            state: state,
            monitor: lidStateMonitor,
            soundPlayer: soundPlayer,
            preferences: preferences
        )
        let lidCloseLockResponder = LidCloseLockResponder(
            state: state,
            monitor: lidStateMonitor,
            screenLocker: screenLocker,
            preferences: preferences,
            policyReader: lockPolicyReader
        )
```

Do not move `LidEventSoundController` below `LidCloseLockResponder`; the responder intentionally wraps the existing lid callback so both sound and lock behavior see each event.

- [x] **Step 3: Run the focused build again**

Run:

```bash
swift build 2>&1 | tail -40
```

Expected: PASS.

- [x] **Step 4: Run all tests after app wiring**

Run:

```bash
swift test 2>&1 | tail -40
```

Expected: PASS with all XCTest tests passing.

- [x] **Step 5: Commit app wiring**

Run:

```bash
git add Sources/Insomnia/AppDelegate.swift
git commit -m "chore: wire macos lock policy reader"
```

Expected: commit succeeds.

---

### Task 4: Update README behavior docs

**Files:**
- Modify: `README.md`

- [x] **Step 1: Update the behavior table and explanatory bullets**

Replace the lock-related rows and bullets in `README.md` under `## Behavior` with this content:

```markdown
  | Preference | Default | What it does |
  |---|---|---|
   | Prevent display sleep | ON | Holds a display-sleep assertion in addition to the no-idle assertion. Mostly meaningful for external displays while the lid is open. |
   | Prevent system sleep with lid closed | OFF | Engages the privileged helper to keep the Mac awake when the lid closes. Requires one-time admin authorization and a confirmation alert. |
   | Play lid event sounds | ON | Plays the macOS Hero sound on lid close and Basso on lid open while Insomnia is on and lid-close sleep prevention is enabled. The row is disabled while lid-close sleep prevention is off. |
   | Launch at login | OFF | Registers Insomnia as a macOS login item. The checkbox reflects the actual login-item state reported by macOS. |

- **When Insomnia is off:** all preferences are inert. No assertions are held, no helper calls are made, and Insomnia does not run a separate lock action.
- **When Insomnia is on and lid-close prevention is off:** closing the lid follows native macOS behavior. The Mac may sleep and lock according to your system settings.
- **When lid-close prevention is on and display sleep is prevented:** Insomnia keeps the Mac awake and intentionally suppresses the native display-off path, so it does not run a separate lid-close lock timer.
- **When lid-close prevention is on and display sleep is allowed:** Insomnia mirrors macOS lock policy. If **Require password** is **Never**, Insomnia does not lock on lid close. Otherwise, it locks after the active display-off timer plus the Require Password delay, and cancels that pending lock if the lid reopens first.
```

- [x] **Step 2: Verify stale lock-row docs are gone**

Run:

```bash
rg -n "Lock screen on lid close|separate lid-close lock action|lock action fires" README.md
```

Expected: no matches.

- [x] **Step 3: Commit README update**

Run:

```bash
git add README.md
git commit -m "docs: explain macos-matched lid-close locking"
```

Expected: commit succeeds.

---

### Task 5: Final verification and task memory update

**Files:**
- Modify: `docs/feat/20260426115000-macos-lock-policy-lid-close-timing/context.md`

- [x] **Step 1: Run full automated verification**

Run:

```bash
make test 2>&1 | tail -40
```

Expected: PASS with all XCTest tests passing.

- [x] **Step 2: Build the app bundle**

Run:

```bash
make app 2>&1 | tail -40
```

Expected: PASS and `build/Insomnia.app` recreated and signed.

- [x] **Step 3: Verify no stale immediate-lock language remains in source docs**

Run:

```bash
rg -n "locks the screen when the lid closes|lock as soon as the lid closes|immediate.*lid" README.md Sources Tests
```

Expected: no matches.

- [x] **Step 4: Update task memory**

Append this log entry to `docs/feat/20260426115000-macos-lock-policy-lid-close-timing/context.md`, adjusting test counts and commit SHAs to the actual results:

```markdown
### 2026-04-26 12:30 — macOS-matched lid-close lock timing implemented

- Why: Insomnia should not create a separate lid-close security policy; it should respect macOS Require Password and display-off timing.
- How: Added `MacOSLockPolicyReader`, delayed/cancellable `LidCloseLockResponder` scheduling, production app wiring, and README docs. Verification: `make test` passed, `make app` passed, and stale immediate-lock wording check passed.
- Decision: Lock timing is read once at lid close and rechecked for active/lid/preference gates before firing; power-source changes while already closed are left as a future refinement.
```

Also update the `## PLAN` cursor to:

```markdown
**Cursor:** Complete — implementation and verification finished.

**Status:** done
```

- [x] **Step 5: Commit task memory update**

Run:

```bash
git add docs/feat/20260426115000-macos-lock-policy-lid-close-timing/context.md
git commit -m "docs: record macos lock timing implementation"
```

Expected: commit succeeds.

---

## Manual Verification Checklist

Run these on a MacBook after automated verification:

- [ ] Set Require Password to Never, turn Insomnia on, enable lid-close prevention, allow display sleep, close and reopen after longer than the display-off timer: session is not locked by Insomnia.
- [ ] Set Require Password to Immediately and battery display-off timer to 1 minute, run on battery, close lid, wait under 1 minute, reopen: not locked yet.
- [ ] Same settings, close lid and wait over 1 minute, reopen: lock screen is shown.
- [ ] Set Require Password delay to a positive value, confirm lock happens after display timer plus that delay.
- [ ] On AC power, confirm the AC display-off timer is used instead of the battery timer.
- [ ] Close lid with a pending lock, reopen before the delay: pending lock cancels.

Manual verification may remain pending if physical lid testing is not available in the current session; record that explicitly in `context.md` instead of marking it verified.
