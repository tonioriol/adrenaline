# Configurable Lid-Close Behavior Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Cocaine's bundled "on = idle + lid-close" toggle with an opt-in, persisted preference model exposed as inline checkboxes in the right-click menu, while reconciling actual behavior live when settings change.

**Architecture:** Add a `PreferencesStore` (UserDefaults-backed observable) that all consumers read; refactor `AwakeController` to take a `preventDisplaySleep` flag with live reconciliation; refactor `AppCoordinator` to consult the store and skip the helper when lid-close prevention is off; gate `LidEventSoundController` on a sound preference; add a sibling `LidCloseLockResponder` driven by a `ScreenLocker` protocol; extend `MenuBarController` with checkbox menu items, a first-time confirmation alert, and routing of clicks to either the store or the coordinator.

**Tech Stack:** Swift 5.9, SwiftPM, AppKit, Combine, IOKit power assertions, `UserDefaults`, private `login` framework via `dlopen`/`dlsym` for `SACLockScreenImmediate`, XCTest. Targets: `CocaineCore` (library), `Cocaine` (app executable), `CocaineHelper` (privileged helper, untouched), `CocaineCoreTests` (XCTest).

---

## File Structure

**Create:**
- `Sources/CocaineCore/PreferencesStore.swift` — observable settings store + protocol + snapshot type.
- `Sources/CocaineCore/ScreenLocker.swift` — `ScreenLocking` protocol + concrete `LoginFrameworkScreenLocker` impl.
- `Sources/CocaineCore/LidCloseLockResponder.swift` — observes `LidStateMonitoring`, gates lock on prefs + active state.
- `Tests/CocaineCoreTests/PreferencesStoreTests.swift` — defaults, round-trip, publishing, suite isolation.
- `Tests/CocaineCoreTests/LidCloseLockResponderTests.swift` — gating matrix + open-never-locks + lock-throws-no-crash.

**Modify:**
- `Sources/CocaineCore/AwakeController.swift` — `enable(preventDisplaySleep:)`, `setPreventDisplaySleep(_:)`, internal split of system / display assertion IDs.
- `Sources/CocaineCore/AppCoordinator.swift` — accept `PreferencesProviding`, conditional lid-close engagement, `setPreventDisplaySleep(_:)` and `setPreventLidCloseSleep(_:)` reconciliation methods, track engaged scope.
- `Sources/CocaineCore/AppState.swift` — add `recordErrorWhileActive(_:)` for live-reconciliation failures that should not flip `isActive`.
- `Sources/CocaineCore/LidEventSoundController.swift` — accept `PreferencesProviding`, gate `play(named:)` calls on `playLidEventSounds`.
- `Sources/Cocaine/AppDelegate.swift` — construct `PreferencesStore`, `ScreenLocker`, `LidCloseLockResponder`; inject store into coordinator + sound controller + menu bar controller.
- `Sources/Cocaine/MenuBarController.swift` — accept `PreferencesStore`; build extended checkbox menu; route clicks; first-time confirmation alert.
- `Tests/CocaineCoreTests/AppStateTests.swift` — extend with `recordErrorWhileActive` test.
- `Tests/CocaineCoreTests/AwakeControllerTests.swift` — extend with display-flag tests and live reconciliation tests.
- `Tests/CocaineCoreTests/AppCoordinatorTests.swift` — extend with prefs-aware tests and live reconciliation tests; existing tests get a default `FakePreferencesStore` injected.
- `Tests/CocaineCoreTests/LidEventSoundControllerTests.swift` — extend with sound-pref gating tests; existing tests get a default `FakePreferencesStore` injected.
- `README.md` — document the new menu items, defaults, and the safety regression for upgraders.

**Untouched:** `Sources/CocaineHelper/**`, `Sources/CocaineCore/CocaineHelperProtocol.swift`, `Sources/CocaineCore/PrivilegedHelperClient.swift`, `Sources/CocaineCore/LidCloseController.swift`, `Sources/CocaineCore/LidStateMonitor.swift`, `Sources/CocaineCore/PowerAssertionClient.swift`, `Resources/**`, `Makefile`, `Package.swift` (no new targets — `ScreenLocker` uses `dlopen` so no new framework link is required).

---

## Task 1: PreferencesStore — protocol, snapshot, and concrete UserDefaults impl

**Files:**
- Create: `Sources/CocaineCore/PreferencesStore.swift`
- Test: `Tests/CocaineCoreTests/PreferencesStoreTests.swift`

- [x] **Step 1: Write the failing test**

Create `Tests/CocaineCoreTests/PreferencesStoreTests.swift`:

```swift
import Combine
import XCTest
@testable import CocaineCore

@MainActor
final class PreferencesStoreTests: XCTestCase {
    private func makeIsolatedDefaults(file: StaticString = #file, line: UInt = #line) -> UserDefaults {
        let suiteName = "CocaineTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create test UserDefaults suite", file: file, line: line)
            return UserDefaults.standard
        }
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    func testEmptyDefaultsYieldSpecDefaults() {
        let defaults = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: defaults)

        XCTAssertTrue(store.preventDisplaySleep)
        XCTAssertFalse(store.preventLidCloseSleep)
        XCTAssertTrue(store.lockScreenOnLidClose)
        XCTAssertTrue(store.playLidEventSounds)
        XCTAssertFalse(store.lidClosePreventionConfirmed)
    }

    func testEachPreferenceRoundTripsThroughUserDefaults() {
        let defaults = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: defaults)

        store.preventDisplaySleep = false
        store.preventLidCloseSleep = true
        store.lockScreenOnLidClose = false
        store.playLidEventSounds = false
        store.lidClosePreventionConfirmed = true

        let reloaded = PreferencesStore(defaults: defaults)
        XCTAssertFalse(reloaded.preventDisplaySleep)
        XCTAssertTrue(reloaded.preventLidCloseSleep)
        XCTAssertFalse(reloaded.lockScreenOnLidClose)
        XCTAssertFalse(reloaded.playLidEventSounds)
        XCTAssertTrue(reloaded.lidClosePreventionConfirmed)
    }

    func testSnapshotMirrorsCurrentValues() {
        let defaults = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: defaults)

        store.preventDisplaySleep = false
        store.preventLidCloseSleep = true
        store.lockScreenOnLidClose = false
        store.playLidEventSounds = false

        let snapshot = store.snapshot()
        XCTAssertFalse(snapshot.preventDisplaySleep)
        XCTAssertTrue(snapshot.preventLidCloseSleep)
        XCTAssertFalse(snapshot.lockScreenOnLidClose)
        XCTAssertFalse(snapshot.playLidEventSounds)
    }

    func testPreferencePublisherEmitsOnChange() {
        let defaults = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: defaults)
        var seen: [Bool] = []
        let cancellable = store.$preventLidCloseSleep.sink { seen.append($0) }

        store.preventLidCloseSleep = true
        store.preventLidCloseSleep = false

        XCTAssertEqual(seen, [false, true, false])
        cancellable.cancel()
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --filter PreferencesStoreTests 2>&1 | tail -30`
Expected: FAIL — `cannot find 'PreferencesStore' in scope`.

- [x] **Step 3: Write minimal implementation**

Create `Sources/CocaineCore/PreferencesStore.swift`:

```swift
import Combine
import Foundation

public struct PreferencesSnapshot: Equatable, Sendable {
    public var preventDisplaySleep: Bool
    public var preventLidCloseSleep: Bool
    public var lockScreenOnLidClose: Bool
    public var playLidEventSounds: Bool

    public init(
        preventDisplaySleep: Bool,
        preventLidCloseSleep: Bool,
        lockScreenOnLidClose: Bool,
        playLidEventSounds: Bool
    ) {
        self.preventDisplaySleep = preventDisplaySleep
        self.preventLidCloseSleep = preventLidCloseSleep
        self.lockScreenOnLidClose = lockScreenOnLidClose
        self.playLidEventSounds = playLidEventSounds
    }
}

@MainActor
public protocol PreferencesProviding: AnyObject {
    var preventDisplaySleep: Bool { get set }
    var preventLidCloseSleep: Bool { get set }
    var lockScreenOnLidClose: Bool { get set }
    var playLidEventSounds: Bool { get set }
    var lidClosePreventionConfirmed: Bool { get set }

    var preventDisplaySleepPublisher: AnyPublisher<Bool, Never> { get }
    var preventLidCloseSleepPublisher: AnyPublisher<Bool, Never> { get }
    var lockScreenOnLidClosePublisher: AnyPublisher<Bool, Never> { get }
    var playLidEventSoundsPublisher: AnyPublisher<Bool, Never> { get }

    func snapshot() -> PreferencesSnapshot
}

@MainActor
public final class PreferencesStore: ObservableObject, PreferencesProviding {
    public enum Key {
        public static let preventDisplaySleep = "Cocaine.preventDisplaySleep"
        public static let preventLidCloseSleep = "Cocaine.preventLidCloseSleep"
        public static let lockScreenOnLidClose = "Cocaine.lockScreenOnLidClose"
        public static let playLidEventSounds = "Cocaine.playLidEventSounds"
        public static let lidClosePreventionConfirmed = "Cocaine.lidClosePreventionConfirmed"
    }

    private let defaults: UserDefaults

    @Published public var preventDisplaySleep: Bool {
        didSet { defaults.set(preventDisplaySleep, forKey: Key.preventDisplaySleep) }
    }

    @Published public var preventLidCloseSleep: Bool {
        didSet { defaults.set(preventLidCloseSleep, forKey: Key.preventLidCloseSleep) }
    }

    @Published public var lockScreenOnLidClose: Bool {
        didSet { defaults.set(lockScreenOnLidClose, forKey: Key.lockScreenOnLidClose) }
    }

    @Published public var playLidEventSounds: Bool {
        didSet { defaults.set(playLidEventSounds, forKey: Key.playLidEventSounds) }
    }

    @Published public var lidClosePreventionConfirmed: Bool {
        didSet { defaults.set(lidClosePreventionConfirmed, forKey: Key.lidClosePreventionConfirmed) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.preventDisplaySleep = Self.readBool(from: defaults, key: Key.preventDisplaySleep, default: true)
        self.preventLidCloseSleep = Self.readBool(from: defaults, key: Key.preventLidCloseSleep, default: false)
        self.lockScreenOnLidClose = Self.readBool(from: defaults, key: Key.lockScreenOnLidClose, default: true)
        self.playLidEventSounds = Self.readBool(from: defaults, key: Key.playLidEventSounds, default: true)
        self.lidClosePreventionConfirmed = Self.readBool(from: defaults, key: Key.lidClosePreventionConfirmed, default: false)
    }

    public var preventDisplaySleepPublisher: AnyPublisher<Bool, Never> {
        $preventDisplaySleep.eraseToAnyPublisher()
    }

    public var preventLidCloseSleepPublisher: AnyPublisher<Bool, Never> {
        $preventLidCloseSleep.eraseToAnyPublisher()
    }

    public var lockScreenOnLidClosePublisher: AnyPublisher<Bool, Never> {
        $lockScreenOnLidClose.eraseToAnyPublisher()
    }

    public var playLidEventSoundsPublisher: AnyPublisher<Bool, Never> {
        $playLidEventSounds.eraseToAnyPublisher()
    }

    public func snapshot() -> PreferencesSnapshot {
        PreferencesSnapshot(
            preventDisplaySleep: preventDisplaySleep,
            preventLidCloseSleep: preventLidCloseSleep,
            lockScreenOnLidClose: lockScreenOnLidClose,
            playLidEventSounds: playLidEventSounds
        )
    }

    private static func readBool(from defaults: UserDefaults, key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `swift test --filter PreferencesStoreTests 2>&1 | tail -20`
Expected: PASS — 4 tests.

- [x] **Step 5: Run the full suite**

Run: `swift test 2>&1 | tail -10`
Expected: PASS — existing tests still green (44 + 4 = 48).

- [x] **Step 6: Commit**

```bash
git add Sources/CocaineCore/PreferencesStore.swift Tests/CocaineCoreTests/PreferencesStoreTests.swift
git -c commit.gpgsign=false commit -m "feat: add PreferencesStore for Cocaine settings"
```

---

## Task 2: AwakeController — display flag and live reconciliation

**Files:**
- Modify: `Sources/CocaineCore/AwakeController.swift`
- Modify: `Tests/CocaineCoreTests/AwakeControllerTests.swift`

- [x] **Step 1: Write the failing tests**

Append to `Tests/CocaineCoreTests/AwakeControllerTests.swift` (inside `final class AwakeControllerTests`):

```swift
    func testEnableWithoutDisplayFlagCreatesOnlyNoIdleAssertion() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable(preventDisplaySleep: false)

        XCTAssertEqual(client.createdReasons, ["Cocaine is active"])
        XCTAssertTrue(controller.isEnabled)
    }

    func testEnableWithDisplayFlagCreatesBothAssertions() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable(preventDisplaySleep: true)

        XCTAssertEqual(client.createdReasons, ["Cocaine is active", "Cocaine is active"])
        XCTAssertTrue(controller.isEnabled)
    }

    func testSetPreventDisplaySleepReleasesDisplayAssertionWhenTurnedOff() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable(preventDisplaySleep: true)
        try controller.setPreventDisplaySleep(false)

        XCTAssertEqual(client.releasedIDs, [43])
        XCTAssertTrue(controller.isEnabled)
    }

    func testSetPreventDisplaySleepCreatesDisplayAssertionWhenTurnedOn() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable(preventDisplaySleep: false)
        try controller.setPreventDisplaySleep(true)

        XCTAssertEqual(client.createdReasons, ["Cocaine is active", "Cocaine is active"])
        XCTAssertTrue(controller.isEnabled)
    }

    func testSetPreventDisplaySleepIsNoopWhenDisabled() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.setPreventDisplaySleep(true)

        XCTAssertTrue(client.createdReasons.isEmpty)
        XCTAssertFalse(controller.isEnabled)
    }

    func testSetPreventDisplaySleepRevertsOnDisplayCreationFailure() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)
        try controller.enable(preventDisplaySleep: false)

        client.displayCreateError = TestError(errorDescription: "display failed")
        XCTAssertThrowsError(try controller.setPreventDisplaySleep(true))

        XCTAssertEqual(client.createdReasons, ["Cocaine is active"])
        XCTAssertTrue(controller.isEnabled)
    }
```

Also adjust the existing `testEnableCreatesSystemAndDisplayAssertions` test caller (and any test that calls `controller.enable()`) so they pass through the new default — see Step 3 for the source change which keeps `enable()` available without a parameter.

- [x] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AwakeControllerTests 2>&1 | tail -30`
Expected: FAIL — `cannot find 'enable(preventDisplaySleep:)' in scope` and `cannot find 'setPreventDisplaySleep' in scope`.

- [x] **Step 3: Replace the implementation**

Replace `Sources/CocaineCore/AwakeController.swift` with:

```swift
import Foundation

public final class AwakeController: AwakeControlling {
    private let client: PowerAssertionClient
    private var systemAssertionID: UInt32?
    private var displayAssertionID: UInt32?

    public var isEnabled: Bool { systemAssertionID != nil }

    public init(client: PowerAssertionClient = IOKitPowerAssertionClient()) {
        self.client = client
    }

    public func enable() throws {
        try enable(preventDisplaySleep: true)
    }

    public func enable(preventDisplaySleep: Bool) throws {
        guard !isEnabled else { return }

        var rolledBackIDs: [UInt32] = []
        do {
            let systemID = try client.createNoIdleSleepAssertion(reason: "Cocaine is active")
            rolledBackIDs.append(systemID)
            systemAssertionID = systemID

            if preventDisplaySleep {
                let displayID = try client.createDisplaySleepAssertion(reason: "Cocaine is active")
                rolledBackIDs.append(displayID)
                displayAssertionID = displayID
            }
        } catch {
            for id in rolledBackIDs {
                client.releaseAssertion(id: id)
            }
            systemAssertionID = nil
            displayAssertionID = nil
            throw error
        }
    }

    public func setPreventDisplaySleep(_ enabled: Bool) throws {
        guard isEnabled else { return }

        if enabled {
            guard displayAssertionID == nil else { return }
            let displayID = try client.createDisplaySleepAssertion(reason: "Cocaine is active")
            displayAssertionID = displayID
        } else {
            guard let id = displayAssertionID else { return }
            client.releaseAssertion(id: id)
            displayAssertionID = nil
        }
    }

    public func disable() {
        if let id = displayAssertionID {
            client.releaseAssertion(id: id)
            displayAssertionID = nil
        }
        if let id = systemAssertionID {
            client.releaseAssertion(id: id)
            systemAssertionID = nil
        }
    }
}
```

Note: the protocol `AwakeControlling` (defined in [`AppCoordinator.swift`](Sources/CocaineCore/AppCoordinator.swift:3)) only requires `enable()` and `disable()`. `enable(preventDisplaySleep:)` and `setPreventDisplaySleep(_:)` are public extensions on the concrete class. The protocol is widened in Task 3.

- [x] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AwakeControllerTests 2>&1 | tail -20`
Expected: PASS — 10 tests (4 original + 6 new).

- [x] **Step 5: Run the full suite**

Run: `swift test 2>&1 | tail -10`
Expected: PASS — 54 total.

- [x] **Step 6: Commit**

```bash
git add Sources/CocaineCore/AwakeController.swift Tests/CocaineCoreTests/AwakeControllerTests.swift
git -c commit.gpgsign=false commit -m "feat: add display-sleep flag and live reconciliation to AwakeController"
```

---

## Task 3: AppCoordinator — read prefs, conditional helper, live reconciliation

**Files:**
- Modify: `Sources/CocaineCore/AppState.swift`
- Modify: `Sources/CocaineCore/AppCoordinator.swift`
- Modify: `Tests/CocaineCoreTests/AppStateTests.swift`
- Modify: `Tests/CocaineCoreTests/AppCoordinatorTests.swift`

- [ ] **Step 0: Add `recordErrorWhileActive(_:)` to `AppState`**

The existing [`AppState.recordError(_:)`](Sources/CocaineCore/AppState.swift:54) flips `isActive` to `false`, which is correct for full activation failures but wrong for live reconciliation failures where awake stays engaged. Add a sibling method that records the error message without disturbing `isActive`.

Append a new test inside `final class AppStateTests` (file: `Tests/CocaineCoreTests/AppStateTests.swift`):

```swift
    func testRecordErrorWhileActiveKeepsActiveButSetsErrorAndHelperFailed() {
        let state = AppState(isActive: true, isBusy: true)
        state.recordErrorWhileActive("display assertion failed")

        XCTAssertTrue(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertEqual(state.lastErrorMessage, "display assertion failed")
        XCTAssertEqual(state.helperState, .failed(message: "display assertion failed"))
    }
```

Run: `swift test --filter AppStateTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'recordErrorWhileActive' in scope`.

In `Sources/CocaineCore/AppState.swift`, append (inside the `AppState` class, just after `recordError`):

```swift
    public func recordErrorWhileActive(_ message: String) {
        isBusy = false
        lastErrorMessage = message
        helperState = .failed(message: message)
    }
```

Run: `swift test --filter AppStateTests 2>&1 | tail -20`
Expected: PASS — existing AppState tests plus the new one.

Commit:

```bash
git add Sources/CocaineCore/AppState.swift Tests/CocaineCoreTests/AppStateTests.swift
git -c commit.gpgsign=false commit -m "feat: add recordErrorWhileActive for live reconciliation failures"
```

- [ ] **Step 1: Widen `AwakeControlling` protocol and add a fake-prefs helper to the existing tests**

In `Sources/CocaineCore/AppCoordinator.swift`, replace the `AwakeControlling` protocol declaration:

```swift
public protocol AwakeControlling: AnyObject {
    func enable() throws
    func enable(preventDisplaySleep: Bool) throws
    func setPreventDisplaySleep(_ enabled: Bool) throws
    func disable()
}
```

Run: `swift build 2>&1 | tail -20`
Expected: FAIL on `FakeAwakeController` in tests not conforming. We address it next.

In `Tests/CocaineCoreTests/AppCoordinatorTests.swift`, replace the existing `private final class FakeAwakeController: AwakeControlling` block with the prefs-aware version:

```swift
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
```

Run: `swift build 2>&1 | tail -10`
Expected: build succeeds (test target builds with new fake conforming).

- [ ] **Step 2: Add a `FakePreferencesStore` and write the failing prefs-aware tests**

Append at the top of `Tests/CocaineCoreTests/AppCoordinatorTests.swift` (after the existing `SuspendedEnableLidCloseController` block, before `private struct TestError`):

```swift
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
```

Add `import Combine` to the top of the file if not already present.

Append the new test cases inside `final class AppCoordinatorTests`:

```swift
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
```

Update every existing test that constructs `AppCoordinator(state:awakeController:lidCloseController:)` — they need a `preferences: FakePreferencesStore()` argument. Concretely:
- Replace each `AppCoordinator(state: state, awakeController: awake, lidCloseController: lid)` with `AppCoordinator(state: state, awakeController: awake, lidCloseController: lid, preferences: FakePreferencesStore())` for callers that don't already define `prefs`.
- For tests where the existing semantic was "lid-close was engaged" (turn-off tests, shutdown tests, rollback tests), use `let prefs = FakePreferencesStore(); prefs.preventLidCloseSleep = true` and pass `preferences: prefs` so the coordinator engages the helper this session and the existing assertions still hold.
- The two existing tests that begin with `state = AppState(isActive: true)` and `lid.isEnabled = true` skip the turn-on flow entirely, so they need the coordinator to behave as if lid-close was engaged previously. Pass `prefs.preventLidCloseSleep = true` AND set the coordinator's session-scope manually via a new test-only seam, OR simpler: change those tests to call `await coordinator.turnOn()` first. Use the `turnOn()` approach to keep production code minimal.

Concrete edits to existing tests:

```swift
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --filter AppCoordinatorTests 2>&1 | tail -30`
Expected: FAIL — `extra argument 'preferences' in call`, `cannot find 'setPreventDisplaySleep'`, `cannot find 'setPreventLidCloseSleep'`.

- [ ] **Step 4: Replace AppCoordinator implementation**

Replace `Sources/CocaineCore/AppCoordinator.swift` with:

```swift
import Foundation

public protocol AwakeControlling: AnyObject {
    func enable() throws
    func enable(preventDisplaySleep: Bool) throws
    func setPreventDisplaySleep(_ enabled: Bool) throws
    func disable()
}

public protocol LidCloseControlling: AnyObject {
    func enable() async throws
    func disable() async throws
    func status() async throws -> Bool
}

public enum AppCoordinatorError: Error, LocalizedError, Equatable {
    case lidCloseStatusDidNotBecomeActive
    case lidCloseStatusRemainedActiveAfterDisable

    public var errorDescription: String? {
        switch self {
        case .lidCloseStatusDidNotBecomeActive:
            return "Lid-close prevention did not become active"
        case .lidCloseStatusRemainedActiveAfterDisable:
            return "Lid-close prevention remained active after disable"
        }
    }
}

@MainActor
public final class AppCoordinator {
    private let state: AppState
    private let awakeController: AwakeControlling
    private let lidCloseController: LidCloseControlling
    private let preferences: PreferencesProviding
    private var shutdownRequested = false
    private var currentTransitionTask: Task<Void, Never>?
    private var lidCloseEngagedThisSession = false

    public init(
        state: AppState,
        awakeController: AwakeControlling,
        lidCloseController: LidCloseControlling,
        preferences: PreferencesProviding
    ) {
        self.state = state
        self.awakeController = awakeController
        self.lidCloseController = lidCloseController
        self.preferences = preferences
    }

    public func toggle() async {
        if state.isActive {
            await turnOff()
        } else {
            await turnOn()
        }
    }

    public func turnOn() async {
        await runTransition {
            await self.performTurnOn()
        }
    }

    public func turnOff() async {
        await runTransition {
            await self.performTurnOff(force: false)
        }
    }

    public func shutdownCleanup() async {
        shutdownRequested = true
        let inFlightTransition = currentTransitionTask
        await inFlightTransition?.value
        await performTurnOff(force: true)
    }

    public func setPreventDisplaySleep(_ enabled: Bool) async {
        await runTransition {
            await self.performSetPreventDisplaySleep(enabled)
        }
    }

    public func setPreventLidCloseSleep(_ enabled: Bool) async {
        await runTransition {
            await self.performSetPreventLidCloseSleep(enabled)
        }
    }

    private func runTransition(_ operation: @escaping @MainActor () async -> Void) async {
        guard !shutdownRequested, !state.isBusy, currentTransitionTask == nil else { return }

        let task = Task { @MainActor in
            await operation()
        }
        currentTransitionTask = task
        await task.value
        currentTransitionTask = nil
    }

    private func performTurnOn() async {
        let snapshot = preferences.snapshot()
        state.setBusy(true)
        state.clearError()

        do {
            try awakeController.enable(preventDisplaySleep: snapshot.preventDisplaySleep)

            if snapshot.preventLidCloseSleep {
                try await lidCloseController.enable()
                lidCloseEngagedThisSession = true

                if shutdownRequested {
                    await rollbackForShutdown()
                    return
                }

                guard try await lidCloseController.status() else {
                    throw AppCoordinatorError.lidCloseStatusDidNotBecomeActive
                }
            }

            if shutdownRequested {
                await rollbackForShutdown()
                return
            }

            state.setActive(true)
            state.setBusy(false)
        } catch {
            awakeController.disable()
            try? await lidCloseController.disable()
            lidCloseEngagedThisSession = false
            state.recordError(error.localizedDescription)
        }
    }

    private func rollbackForShutdown() async {
        awakeController.disable()
        try? await lidCloseController.disable()
        lidCloseEngagedThisSession = false
        state.setActive(false)
        state.setBusy(false)
    }

    private func performTurnOff(force: Bool) async {
        guard force || !state.isBusy else { return }
        state.setBusy(true)
        awakeController.disable()

        let needsLidCloseDisable = lidCloseEngagedThisSession
        lidCloseEngagedThisSession = false

        guard needsLidCloseDisable else {
            state.setActive(false)
            state.setBusy(false)
            return
        }

        do {
            try await lidCloseController.disable()
            state.setActive(false)
            state.setBusy(false)

            if try await lidCloseController.status() {
                throw AppCoordinatorError.lidCloseStatusRemainedActiveAfterDisable
            }
        } catch {
            state.setActive(false)
            state.setBusy(false)
            state.recordError(error.localizedDescription)
        }
    }

    private func performSetPreventDisplaySleep(_ enabled: Bool) async {
        let previous = preferences.preventDisplaySleep
        preferences.preventDisplaySleep = enabled
        guard state.isActive, previous != enabled else { return }

        do {
            try awakeController.setPreventDisplaySleep(enabled)
        } catch {
            preferences.preventDisplaySleep = previous
            state.recordError(error.localizedDescription)
        }
    }

    private func performSetPreventLidCloseSleep(_ enabled: Bool) async {
        let previous = preferences.preventLidCloseSleep
        preferences.preventLidCloseSleep = enabled
        guard state.isActive, previous != enabled else { return }

        if enabled {
            do {
                try await lidCloseController.enable()
                lidCloseEngagedThisSession = true
                guard try await lidCloseController.status() else {
                    throw AppCoordinatorError.lidCloseStatusDidNotBecomeActive
                }
            } catch {
                try? await lidCloseController.disable()
                lidCloseEngagedThisSession = false
                preferences.preventLidCloseSleep = previous
                state.recordErrorWhileActive(error.localizedDescription)
            }
        } else {
            do {
                try await lidCloseController.disable()
                lidCloseEngagedThisSession = false
            } catch {
                lidCloseEngagedThisSession = false
                state.recordError(error.localizedDescription)
            }
        }
    }
}
```

Note: live lid-close failures use `recordErrorWhileActive(_:)` (added in Step 0) so the icon stays "on with error" — awake is still engaged. Live `performSetPreventDisplaySleep` failures should also call `recordErrorWhileActive(_:)`; update its `catch` block accordingly:

```swift
    private func performSetPreventDisplaySleep(_ enabled: Bool) async {
        let previous = preferences.preventDisplaySleep
        preferences.preventDisplaySleep = enabled
        guard state.isActive, previous != enabled else { return }

        do {
            try awakeController.setPreventDisplaySleep(enabled)
        } catch {
            preferences.preventDisplaySleep = previous
            state.recordErrorWhileActive(error.localizedDescription)
        }
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter AppCoordinatorTests 2>&1 | tail -20`
Expected: PASS — 17 tests (10 original adapted + 7 new).

- [ ] **Step 6: Run the full suite**

Run: `swift test 2>&1 | tail -10`
Expected: PASS — 61 total.

- [ ] **Step 7: Commit**

```bash
git add Sources/CocaineCore/AppCoordinator.swift Tests/CocaineCoreTests/AppCoordinatorTests.swift
git -c commit.gpgsign=false commit -m "feat: drive AppCoordinator from PreferencesStore with live reconciliation"
```

---

## Task 4: LidEventSoundController — gate sounds on preferences

**Files:**
- Modify: `Sources/CocaineCore/LidEventSoundController.swift`
- Modify: `Tests/CocaineCoreTests/LidEventSoundControllerTests.swift`

- [ ] **Step 1: Write failing tests**

Append the `FakePreferencesStore` definition (same shape as in Task 3) to `Tests/CocaineCoreTests/LidEventSoundControllerTests.swift`. Add `import Combine` to the top if missing.

```swift
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
```

Append new tests inside the existing `final class LidEventSoundControllerTests`:

```swift
    func testPlayLidEventSoundsOffSilencesBothEvents() {
        let state = AppState(isActive: true)
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let prefs = FakePreferencesStore()
        prefs.playLidEventSounds = false
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: prefs)

        monitor.emit(.closed)
        monitor.emit(.open)

        XCTAssertTrue(player.playedSoundNames.isEmpty)
        _ = controller
    }

    func testTogglingPlayLidEventSoundsBetweenEventsAffectsOnlyNextEvent() {
        let state = AppState(isActive: true)
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let prefs = FakePreferencesStore()
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: prefs)

        monitor.emit(.closed)
        prefs.playLidEventSounds = false
        monitor.emit(.open)
        prefs.playLidEventSounds = true
        monitor.emit(.closed)

        XCTAssertEqual(player.playedSoundNames, ["Hero", "Hero"])
        _ = controller
    }
```

Update every existing test that constructs `LidEventSoundController(state:monitor:soundPlayer:)` to pass `preferences: FakePreferencesStore()`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter LidEventSoundControllerTests 2>&1 | tail -20`
Expected: FAIL — `extra argument 'preferences' in call`.

- [ ] **Step 3: Update the source**

Replace `Sources/CocaineCore/LidEventSoundController.swift` with:

```swift
import Combine
import Foundation

public enum LidState: Equatable, Sendable {
    case open
    case closed
}

@MainActor
public protocol LidStateMonitoring: AnyObject {
    var onLidStateChange: (@MainActor (LidState) -> Void)? { get set }
    var isMonitoring: Bool { get }
    func start() throws
    func stop()
}

@MainActor
public protocol LidSoundPlaying: AnyObject {
    func play(named soundName: String)
}

@MainActor
public final class LidEventSoundController {
    public static let closeSoundName = "Hero"
    public static let openSoundName = "Basso"

    private let state: AppState
    private let monitor: LidStateMonitoring
    private let soundPlayer: LidSoundPlaying
    private let preferences: PreferencesProviding
    private var cancellable: AnyCancellable?
    private var lastHandledState: LidState?
    private var monitoringStarted = false

    public init(
        state: AppState,
        monitor: LidStateMonitoring,
        soundPlayer: LidSoundPlaying,
        preferences: PreferencesProviding
    ) {
        self.state = state
        self.monitor = monitor
        self.soundPlayer = soundPlayer
        self.preferences = preferences

        monitor.onLidStateChange = { [weak self] lidState in
            self?.handle(lidState)
        }

        cancellable = state.$isActive
            .removeDuplicates()
            .sink { [weak self] isActive in
                self?.setMonitoringEnabled(isActive)
            }
    }

    private func setMonitoringEnabled(_ enabled: Bool) {
        if enabled {
            do {
                try monitor.start()
                monitoringStarted = true
            } catch {
                monitoringStarted = false
            }
        } else {
            monitor.stop()
            monitoringStarted = false
            lastHandledState = nil
        }
    }

    private func handle(_ lidState: LidState) {
        guard state.isActive, monitoringStarted, lidState != lastHandledState else { return }
        lastHandledState = lidState

        guard preferences.playLidEventSounds else { return }

        switch lidState {
        case .closed:
            soundPlayer.play(named: Self.closeSoundName)
        case .open:
            soundPlayer.play(named: Self.openSoundName)
        }
    }
}
```

Note: `lastHandledState` is updated **before** the preference check, so a duplicate event after toggling sounds back on still suppresses correctly (matches existing duplicate-suppression test).

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter LidEventSoundControllerTests 2>&1 | tail -20`
Expected: PASS — 9 tests (7 original + 2 new).

- [ ] **Step 5: Run the full suite**

Run: `swift test 2>&1 | tail -10`
Expected: PASS — 63 total.

- [ ] **Step 6: Commit**

```bash
git add Sources/CocaineCore/LidEventSoundController.swift Tests/CocaineCoreTests/LidEventSoundControllerTests.swift
git -c commit.gpgsign=false commit -m "feat: gate lid event sounds on preferences"
```

---

## Task 5: ScreenLocker protocol + LidCloseLockResponder

**Files:**
- Create: `Sources/CocaineCore/ScreenLocker.swift`
- Create: `Sources/CocaineCore/LidCloseLockResponder.swift`
- Test: `Tests/CocaineCoreTests/LidCloseLockResponderTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/CocaineCoreTests/LidCloseLockResponderTests.swift`:

```swift
import Combine
import XCTest
@testable import CocaineCore

@MainActor
private final class FakeLidStateMonitor: LidStateMonitoring {
    var onLidStateChange: (@MainActor (LidState) -> Void)?
    private(set) var isMonitoring = false

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
    private func makeResponder(isActive: Bool, preventLid: Bool, lockOnClose: Bool)
        -> (FakeLidStateMonitor, FakeScreenLocker, LidCloseLockResponder)
    {
        let state = AppState(isActive: isActive)
        let monitor = FakeLidStateMonitor()
        let locker = FakeScreenLocker()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = preventLid
        prefs.lockScreenOnLidClose = lockOnClose
        let responder = LidCloseLockResponder(state: state, monitor: monitor, screenLocker: locker, preferences: prefs)
        return (monitor, locker, responder)
    }

    func testInactiveStateDoesNotLock() {
        let (monitor, locker, responder) = makeResponder(isActive: false, preventLid: true, lockOnClose: true)
        monitor.emit(.closed)
        XCTAssertEqual(locker.lockCallCount, 0)
        _ = responder
    }

    func testPreventLidCloseOffDoesNotLock() {
        let (monitor, locker, responder) = makeResponder(isActive: true, preventLid: false, lockOnClose: true)
        monitor.emit(.closed)
        XCTAssertEqual(locker.lockCallCount, 0)
        _ = responder
    }

    func testLockOnCloseOffDoesNotLock() {
        let (monitor, locker, responder) = makeResponder(isActive: true, preventLid: true, lockOnClose: false)
        monitor.emit(.closed)
        XCTAssertEqual(locker.lockCallCount, 0)
        _ = responder
    }

    func testAllConditionsMetLocksOnceOnClose() {
        let (monitor, locker, responder) = makeResponder(isActive: true, preventLid: true, lockOnClose: true)
        monitor.emit(.closed)
        XCTAssertEqual(locker.lockCallCount, 1)
        _ = responder
    }

    func testLidOpenNeverLocks() {
        let (monitor, locker, responder) = makeResponder(isActive: true, preventLid: true, lockOnClose: true)
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
        prefs.preventLidCloseSleep = true
        prefs.lockScreenOnLidClose = true
        let responder = LidCloseLockResponder(state: state, monitor: monitor, screenLocker: locker, preferences: prefs)

        monitor.emit(.closed)

        XCTAssertEqual(locker.lockCallCount, 1)
        XCTAssertTrue(state.isActive)
        XCTAssertNil(state.lastErrorMessage)
        _ = responder
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter LidCloseLockResponderTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'ScreenLocking' in scope`, `cannot find 'LidCloseLockResponder' in scope`.

- [ ] **Step 3: Create ScreenLocker source**

Create `Sources/CocaineCore/ScreenLocker.swift`:

```swift
import Foundation
import os.log

@MainActor
public protocol ScreenLocking: AnyObject {
    func lock() throws
}

public enum ScreenLockerError: Error, LocalizedError {
    case symbolUnavailable
    case fallbackFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .symbolUnavailable:
            return "SACLockScreenImmediate is not available on this system"
        case let .fallbackFailed(code):
            return "loginwindow lock fallback failed with status \(code)"
        }
    }
}

@MainActor
public final class LoginFrameworkScreenLocker: ScreenLocking {
    private static let log = OSLog(subsystem: "com.tr0n.Cocaine", category: "ScreenLocker")
    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/login.framework/Versions/A/login"

    private let lockSymbol: (@convention(c) () -> Int32)?

    public init() {
        self.lockSymbol = LoginFrameworkScreenLocker.loadLockSymbol()
    }

    public func lock() throws {
        if let lockSymbol {
            _ = lockSymbol()
            return
        }

        try Self.invokeLoginwindowFallback()
    }

    private static func loadLockSymbol() -> (@convention(c) () -> Int32)? {
        guard let handle = dlopen(frameworkPath, RTLD_LAZY) else {
            os_log("login framework not loadable: %{public}s",
                   log: log,
                   type: .info,
                   String(cString: dlerror() ?? UnsafePointer(("unknown" as NSString).utf8String!)))
            return nil
        }

        guard let symbol = dlsym(handle, "SACLockScreenImmediate") else {
            return nil
        }

        return unsafeBitCast(symbol, to: (@convention(c) () -> Int32).self)
    }

    private static func invokeLoginwindowFallback() throws {
        // CGSession -suspend is the documented public command-line lock-session
        // technique on macOS and is preferred over AppleScript automation
        // (which would require an Automation permission grant).
        let process = Process()
        process.launchPath = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        process.arguments = ["-suspend"]

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                throw ScreenLockerError.fallbackFailed(process.terminationStatus)
            }
        } catch let error as ScreenLockerError {
            throw error
        } catch {
            throw ScreenLockerError.symbolUnavailable
        }
    }
}
```

Note: `CGSession -suspend` is the documented public command-line lock-session technique on macOS and is the safer fallback than AppleScript automation prompts.

- [ ] **Step 4: Create LidCloseLockResponder source**

Create `Sources/CocaineCore/LidCloseLockResponder.swift`:

```swift
import Combine
import Foundation
import os.log

@MainActor
public final class LidCloseLockResponder {
    private static let log = OSLog(subsystem: "com.tr0n.Cocaine", category: "LidCloseLockResponder")

    private let state: AppState
    private let monitor: LidStateMonitoring
    private let screenLocker: ScreenLocking
    private let preferences: PreferencesProviding

    public init(
        state: AppState,
        monitor: LidStateMonitoring,
        screenLocker: ScreenLocking,
        preferences: PreferencesProviding
    ) {
        self.state = state
        self.monitor = monitor
        self.screenLocker = screenLocker
        self.preferences = preferences

        let existing = monitor.onLidStateChange
        monitor.onLidStateChange = { [weak self] lidState in
            existing?(lidState)
            self?.handle(lidState)
        }
    }

    private func handle(_ lidState: LidState) {
        guard lidState == .closed else { return }
        guard state.isActive else { return }
        guard preferences.preventLidCloseSleep else { return }
        guard preferences.lockScreenOnLidClose else { return }

        do {
            try screenLocker.lock()
        } catch {
            os_log("Screen lock failed: %{public}s",
                   log: Self.log,
                   type: .error,
                   error.localizedDescription)
        }
    }
}
```

The responder chains itself onto the existing `onLidStateChange` callback so both `LidEventSoundController` and `LidCloseLockResponder` see every event. Order in `AppDelegate` matters: construct the sound controller first, then the lock responder.

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter LidCloseLockResponderTests 2>&1 | tail -20`
Expected: PASS — 6 tests.

- [ ] **Step 6: Run the full suite**

Run: `swift test 2>&1 | tail -10`
Expected: PASS — 69 total.

- [ ] **Step 7: Commit**

```bash
git add Sources/CocaineCore/ScreenLocker.swift Sources/CocaineCore/LidCloseLockResponder.swift Tests/CocaineCoreTests/LidCloseLockResponderTests.swift
git -c commit.gpgsign=false commit -m "feat: add ScreenLocker and LidCloseLockResponder"
```

---

## Task 6: Wire prefs, screen locker, and lock responder in AppDelegate

**Files:**
- Modify: `Sources/Cocaine/AppDelegate.swift`

> **Construction order matters.** [`LidCloseLockResponder`](Sources/CocaineCore/LidCloseLockResponder.swift:1) chains itself onto the existing `monitor.onLidStateChange` closure inside its initializer, so the sound controller (which sets the first closure) MUST be constructed before the lock responder (which wraps it). The replacement file below already orders the two correctly.

- [ ] **Step 1: Replace AppDelegate**

Replace `Sources/Cocaine/AppDelegate.swift` with:

```swift
import AppKit
import CocaineCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var preferences: PreferencesStore?
    private var menuBarController: MenuBarController?
    private var coordinator: AppCoordinator?
    private var lidEventSoundController: LidEventSoundController?
    private var lidCloseLockResponder: LidCloseLockResponder?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let preferences = PreferencesStore()
        let state = AppState()
        let awake = AwakeController()
        let lidClose = LidCloseController()
        let coordinator = AppCoordinator(
            state: state,
            awakeController: awake,
            lidCloseController: lidClose,
            preferences: preferences
        )
        let lidStateMonitor = LidStateMonitor()
        let soundPlayer = SystemSoundPlayer()
        let screenLocker = LoginFrameworkScreenLocker()

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
            preferences: preferences
        )

        self.preferences = preferences
        self.coordinator = coordinator
        self.lidEventSoundController = lidEventSoundController
        self.lidCloseLockResponder = lidCloseLockResponder
        self.menuBarController = MenuBarController(
            state: state,
            coordinator: coordinator,
            preferences: preferences
        )
    }

    @MainActor
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let coordinator else { return .terminateNow }
        Task { @MainActor in
            await coordinator.shutdownCleanup()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
```

- [ ] **Step 2: Build to verify the wiring compiles**

Run: `swift build 2>&1 | tail -20`
Expected: FAIL — `MenuBarController` does not yet accept a `preferences:` argument. Fix in Task 7.

(Skip the run-the-full-suite step here since the next task touches MenuBarController and they need to commit together to keep the repo building.)

---

## Task 7: MenuBarController — checkbox menu items, click routing, confirmation alert

**Files:**
- Modify: `Sources/Cocaine/MenuBarController.swift`

This task makes `swift build` green again after Task 6.

- [ ] **Step 1: Replace MenuBarController**

Replace `Sources/Cocaine/MenuBarController.swift` with:

```swift
import AppKit
import Combine
import CocaineCore

@MainActor
final class MenuBarController: NSObject {
    private let state: AppState
    private let coordinator: AppCoordinator
    private let preferences: PreferencesStore
    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []

    init(state: AppState, coordinator: AppCoordinator, preferences: PreferencesStore) {
        self.state = state
        self.coordinator = coordinator
        self.preferences = preferences
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusItem()
        bindState()
        render()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func bindState() {
        state.$isActive.receive(on: RunLoop.main).sink { [weak self] _ in self?.render() }.store(in: &cancellables)
        state.$isBusy.receive(on: RunLoop.main).sink { [weak self] _ in self?.render() }.store(in: &cancellables)
        state.$lastErrorMessage.receive(on: RunLoop.main).sink { [weak self] _ in self?.render() }.store(in: &cancellables)
    }

    private func render() {
        guard let button = statusItem.button else { return }
        button.image = statusImage()
        button.toolTip = tooltipText
    }

    private func statusImage() -> NSImage? {
        if state.isBusy {
            return symbolImage(named: "hourglass")
        }

        if state.lastErrorMessage != nil {
            return symbolImage(named: "exclamationmark.triangle")
        }

        return pillImage(filled: state.isActive)
    }

    private func symbolImage(named symbolName: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Cocaine")
        image?.isTemplate = true
        return image
    }

    private func pillImage(filled: Bool) -> NSImage {
        let pillScale: CGFloat = 1.2
        let size = NSSize(width: 21, height: 17)

        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            context.saveGState()
            defer { context.restoreGState() }

            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)

            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: .pi / 6)

            let pillWidth: CGFloat = 13.2 * pillScale
            let pillHeight: CGFloat = 6.5 * pillScale
            let pillRect = CGRect(
                x: -pillWidth / 2,
                y: -pillHeight / 2,
                width: pillWidth,
                height: pillHeight
            )
            let radius = pillRect.height / 2
            let pillPath = CGPath(
                roundedRect: pillRect,
                cornerWidth: radius,
                cornerHeight: radius,
                transform: nil
            )

            context.setStrokeColor(NSColor.black.cgColor)
            context.setFillColor(NSColor.black.cgColor)

            if filled {
                context.addPath(pillPath)
                context.fillPath()

                context.setBlendMode(.clear)
                let splitWidth: CGFloat = 1.9 * pillScale
                let splitInset: CGFloat = 1.75 * pillScale
                let splitRect = CGRect(
                    x: -splitWidth / 2,
                    y: pillRect.minY - splitInset,
                    width: splitWidth,
                    height: pillRect.height + (splitInset * 2)
                )
                context.fill(splitRect)
            } else {
                context.setLineWidth(1.6)
                context.addPath(pillPath)
                context.strokePath()

                context.setLineWidth(1.25)
                let seamOvershoot: CGFloat = 0.9 * pillScale
                context.move(to: CGPoint(x: 0, y: pillRect.minY - seamOvershoot))
                context.addLine(to: CGPoint(x: 0, y: pillRect.maxY + seamOvershoot))
                context.strokePath()
            }

            return true
        }

        image.isTemplate = true
        return image
    }

    private var tooltipText: String {
        if state.isBusy { return "Cocaine is changing sleep prevention state" }
        if state.isActive {
            return preferences.preventLidCloseSleep
                ? "Cocaine is preventing sleep, including lid-close sleep"
                : "Cocaine is preventing sleep"
        }
        if let error = state.lastErrorMessage { return "Cocaine is off: \(error)" }
        return "Cocaine is off"
    }

    @objc
    private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
            return
        }

        Task { @MainActor in
            await coordinator.toggle()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        if let error = state.lastErrorMessage {
            let errorItem = NSMenuItem(title: "Error: \(error)", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
            menu.addItem(NSMenuItem.separator())
        }

        let aboutItem = NSMenuItem(title: "About Cocaine", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeCheckboxItem(
            title: "Prevent display sleep",
            isOn: preferences.preventDisplaySleep,
            action: #selector(togglePreventDisplaySleep)
        ))

        let lidCloseTitle = preferences.preventLidCloseSleep
            ? "⚠ Prevent sleep with lid closed"
            : "Prevent sleep with lid closed"
        menu.addItem(makeCheckboxItem(
            title: lidCloseTitle,
            isOn: preferences.preventLidCloseSleep,
            action: #selector(togglePreventLidCloseSleep)
        ))

        let lockItem = makeCheckboxItem(
            title: "    Lock screen when lid closes",
            isOn: preferences.lockScreenOnLidClose,
            action: #selector(toggleLockScreenOnLidClose)
        )
        lockItem.isEnabled = preferences.preventLidCloseSleep
        menu.addItem(lockItem)

        menu.addItem(makeCheckboxItem(
            title: "Play lid event sounds",
            isOn: preferences.playLidEventSounds,
            action: #selector(togglePlayLidEventSounds)
        ))

        menu.addItem(NSMenuItem.separator())

        let repairItem = NSMenuItem(title: "Repair / Install Helper", action: #selector(repairHelper), keyEquivalent: "")
        repairItem.target = self
        repairItem.isEnabled = state.lastErrorMessage != nil
        menu.addItem(repairItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func makeCheckboxItem(title: String, isOn: Bool, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = isOn ? .on : .off
        return item
    }

    @objc
    private func togglePreventDisplaySleep() {
        let newValue = !preferences.preventDisplaySleep
        Task { @MainActor in
            await coordinator.setPreventDisplaySleep(newValue)
        }
    }

    @objc
    private func togglePreventLidCloseSleep() {
        let newValue = !preferences.preventLidCloseSleep
        if newValue && !preferences.lidClosePreventionConfirmed {
            guard confirmLidClosePreventionEnable() else { return }
            preferences.lidClosePreventionConfirmed = true
        }
        if !newValue {
            preferences.lidClosePreventionConfirmed = false
        }
        Task { @MainActor in
            await coordinator.setPreventLidCloseSleep(newValue)
        }
    }

    private func confirmLidClosePreventionEnable() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Prevent sleep with lid closed?"
        alert.informativeText = "Preventing lid-close sleep can leave a closed MacBook running. " +
            "Don't put it in a bag while this is enabled — it may overheat."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Enable")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    @objc
    private func toggleLockScreenOnLidClose() {
        preferences.lockScreenOnLidClose.toggle()
    }

    @objc
    private func togglePlayLidEventSounds() {
        preferences.playLidEventSounds.toggle()
    }

    @objc
    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: "Personal keep-awake utility inspired by Caffeine and Fermata."),
        ])
    }

    @objc
    private func repairHelper() {
        Task { @MainActor in
            await coordinator.turnOn()
        }
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 2: Build the package**

Run: `swift build 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 3: Build the app bundle**

Run: `make app 2>&1 | tail -10`
Expected: PASS — `build/Cocaine.app` created.

- [ ] **Step 4: Run the full test suite**

Run: `swift test 2>&1 | tail -10`
Expected: PASS — 69 total.

- [ ] **Step 5: Commit**

```bash
git add Sources/Cocaine/AppDelegate.swift Sources/Cocaine/MenuBarController.swift
git -c commit.gpgsign=false commit -m "feat: surface preference checkboxes in menu bar with confirmation alert"
```

---

## Task 8: README — document new behavior, defaults, and upgrade note

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace README behavior section**

Replace `README.md` with:

```markdown
# Cocaine

Personal macOS menu bar app with one on/off icon. When on, it prevents idle sleep using public IOKit assertions. Optional preferences extend that to display sleep, full lid-close sleep prevention, and screen locking on lid close.

## Safety

Do not put a closed MacBook into a bag with **Prevent sleep with lid closed** enabled. Lid-close sleep prevention can leave the machine running and may cause overheating.

## Build

```bash
make test
make app
```

The app bundle is created at `build/Cocaine.app`.

## Run

```bash
make run
```

The first time you enable **Prevent sleep with lid closed**, macOS asks for admin authorization to install the privileged helper that controls lid-close behavior.

## Behavior

- **Left-click menu bar icon:** toggle Cocaine off ↔ on. While on, your current preferences are enforced.
- **Right-click menu bar icon:** opens a menu with these checkbox preferences (saved across launches):

  | Preference | Default | What it does |
  |---|---|---|
  | Prevent display sleep | ON | Holds a display-sleep assertion in addition to the no-idle assertion. Mostly meaningful for external displays while the lid is open. |
  | Prevent sleep with lid closed | OFF | Engages the privileged helper to keep the Mac awake when the lid closes. Requires one-time admin authorization and a confirmation alert. |
  | Lock screen when lid closes | ON | When lid-close prevention is on, locks your session as soon as the lid closes (Mac stays awake, screen blanks, session locked). |
  | Play lid event sounds | ON | Plays the macOS Hero sound on lid close and Basso on lid open while Cocaine is on. |

- **When Cocaine is off:** all preferences are inert. No assertions are held, no helper calls are made, no lock action fires.
- **When Cocaine is on and lid-close prevention is off:** the Mac sleeps normally on lid close (no sounds, no lock — there is no event to react to).
- **Repair / Install Helper:** appears in the menu when helper setup or communication has failed.

## Upgrading from earlier versions

Earlier versions enabled lid-close sleep prevention as part of the single on/off toggle. This version makes lid-close prevention an explicit opt-in — its default after upgrade is **off**. To restore the old behavior, right-click the menu bar icon and check **Prevent sleep with lid closed** once.
```

- [ ] **Step 2: Verify README is internally consistent**

Run: `git diff -- README.md | head -80`
Expected: shows the rewrite. No build/test step needed for docs.

- [ ] **Step 3: Commit**

```bash
git add README.md
git -c commit.gpgsign=false commit -m "docs: describe lid-close behavior preferences"
```

---

## Task 9: Final verification and manual checklist note

**Files:** none modified — verification only.

- [ ] **Step 1: Clean build + full test run**

Run: `make clean && make test 2>&1 | tail -20`
Expected: PASS — at least 69 XCTest tests.

- [ ] **Step 2: App bundle build**

Run: `make app 2>&1 | tail -10`
Expected: PASS — `build/Cocaine.app` created and signed.

- [ ] **Step 3: Smoke-launch the bundle**

Run: `open build/Cocaine.app && sleep 2 && pgrep -lf Cocaine.app/Contents/MacOS/Cocaine`
Expected: PID printed.

- [ ] **Step 4: Quit cleanly**

Run: `pkill -f 'Cocaine.app/Contents/MacOS/Cocaine' && sleep 1 && pgrep -lf Cocaine.app/Contents/MacOS/Cocaine ; echo "exit=$?"`
Expected: `exit=1` (no process — pgrep prints nothing and exits 1).

- [ ] **Step 5: Confirm no lingering Cocaine power assertions**

Run: `pmset -g assertions | grep -i cocaine ; echo "exit=$?"`
Expected: `exit=1` (no Cocaine-named assertion remains).

- [ ] **Step 6: Print the manual validation checklist**

Print to the conversation (do not commit):

```
Manual validation steps requiring physical hardware (out of scope for automated verification):

1. Right-click menu shows the four checkboxes with defaults: display=on, lid-close=off, lock=on, sounds=on.
2. Toggling lid-close-prevention on → confirmation alert appears once; cancelling leaves preference unchecked.
3. Cocaine on, lid-close on, lock-on-close on, close lid → reopen → finds lock screen.
4. Cocaine on, lid-close on, lock-on-close off, close lid → reopen → finds session unlocked.
5. Cocaine on, lid-close on → toggle Cocaine off via icon → SleepDisabled returns to false (verify with `pmset -g | grep SleepDisabled`).
6. Quit while lid-close on → relaunch → checkbox still on, but actual `SleepDisabled` only re-engages on next turn-on.
7. Cocaine on with lid-close off, close lid → Mac sleeps normally (no sounds, no lock).
```

- [ ] **Step 7: No commit needed for verification-only task**

This task ends without a commit. The previous tasks left the repo in a final, working state.
