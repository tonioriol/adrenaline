# Lid Event Sounds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add passive app-side lid event monitoring that plays Hero when the lid closes and Basso when the lid opens while Cocaine is active.

**Architecture:** Keep lid sounds as app-side feedback. `CocaineCore` owns the testable lid event policy and passive IOKit lid monitor; the app executable owns the AppKit `NSSound` wrapper and lifecycle wiring. The privileged helper remains unchanged and continues only managing lid-close sleep prevention.

**Tech Stack:** Swift 5.9, SwiftPM, XCTest, Combine, AppKit `NSSound`, IOKit general-interest notifications from `IOPMrootDomain`.

---

## File Structure

- Create `Sources/CocaineCore/LidEventSoundController.swift` — defines normalized lid state, testable monitor/player protocols, and active-state sound policy.
- Create `Sources/CocaineCore/LidStateMonitor.swift` — concrete passive IOKit monitor for clamshell state changes.
- Create `Sources/Cocaine/SystemSoundPlayer.swift` — AppKit `NSSound` wrapper for built-in macOS sound names.
- Modify `Sources/Cocaine/AppDelegate.swift` — instantiate and retain the lid sound controller next to existing app services.
- Create `Tests/CocaineCoreTests/LidEventSoundControllerTests.swift` — policy tests with fake monitor and fake sound player.
- Create `Tests/CocaineCoreTests/LidStateMonitorTests.swift` — deterministic tests for clamshell message decoding constants.
- Modify `README.md` — document Hero close sound and Basso open sound.

---

### Task 1: Lid Event Sound Policy

**Files:**
- Create: `Tests/CocaineCoreTests/LidEventSoundControllerTests.swift`
- Create: `Sources/CocaineCore/LidEventSoundController.swift`

- [x] **Step 1: Write failing policy tests**

Create `Tests/CocaineCoreTests/LidEventSoundControllerTests.swift`:

```swift
import XCTest
@testable import CocaineCore

@MainActor
private final class FakeLidStateMonitor: LidStateMonitoring {
    var onLidStateChange: (@MainActor (LidState) -> Void)?
    private(set) var isMonitoring = false
    var startCallCount = 0
    var stopCallCount = 0
    var startError: Error?

    func start() throws {
        startCallCount += 1
        if let startError { throw startError }
        isMonitoring = true
    }

    func stop() {
        stopCallCount += 1
        isMonitoring = false
    }

    func emit(_ lidState: LidState) {
        onLidStateChange?(lidState)
    }
}

private final class FakeLidSoundPlayer: LidSoundPlaying {
    private(set) var playedSoundNames: [String] = []

    func play(named soundName: String) {
        playedSoundNames.append(soundName)
    }
}

private struct TestError: Error, LocalizedError {
    let errorDescription: String?
}

@MainActor
final class LidEventSoundControllerTests: XCTestCase {
    func testBecomingActiveStartsMonitoring() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player)

        state.setActive(true)

        XCTAssertTrue(monitor.isMonitoring)
        XCTAssertEqual(monitor.startCallCount, 1)
        XCTAssertTrue(player.playedSoundNames.isEmpty)
        _ = controller
    }

    func testCloseEventWhileActivePlaysHero() {
        let state = AppState(isActive: true)
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player)

        monitor.emit(.closed)

        XCTAssertEqual(player.playedSoundNames, ["Hero"])
        _ = controller
    }

    func testOpenEventWhileActivePlaysBasso() {
        let state = AppState(isActive: true)
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player)

        monitor.emit(.open)

        XCTAssertEqual(player.playedSoundNames, ["Basso"])
        _ = controller
    }

    func testLidEventsWhileInactivePlayNoSounds() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player)

        monitor.emit(.closed)
        monitor.emit(.open)

        XCTAssertTrue(player.playedSoundNames.isEmpty)
        XCTAssertFalse(monitor.isMonitoring)
        _ = controller
    }

    func testDuplicateLidStatesDoNotReplaySounds() {
        let state = AppState(isActive: true)
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player)

        monitor.emit(.closed)
        monitor.emit(.closed)
        monitor.emit(.open)
        monitor.emit(.open)
        monitor.emit(.closed)

        XCTAssertEqual(player.playedSoundNames, ["Hero", "Basso", "Hero"])
        _ = controller
    }

    func testDeactivationStopsMonitoringAndClearsDuplicateState() {
        let state = AppState(isActive: true)
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player)

        monitor.emit(.closed)
        state.setActive(false)
        XCTAssertFalse(monitor.isMonitoring)

        state.setActive(true)
        monitor.emit(.closed)

        XCTAssertTrue(monitor.isMonitoring)
        XCTAssertEqual(player.playedSoundNames, ["Hero", "Hero"])
        _ = controller
    }

    func testMonitorStartFailureDoesNotChangeAppStateOrPlaySounds() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        monitor.startError = TestError(errorDescription: "monitor unavailable")
        let player = FakeLidSoundPlayer()
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player)

        state.setActive(true)
        monitor.emit(.closed)

        XCTAssertTrue(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertNil(state.lastErrorMessage)
        XCTAssertEqual(state.helperState, .unknown)
        XCTAssertFalse(monitor.isMonitoring)
        XCTAssertTrue(player.playedSoundNames.isEmpty)
        _ = controller
    }
}
```

- [x] **Step 2: Run policy tests to verify they fail**

Run:

```bash
swift test --filter LidEventSoundControllerTests
```

Expected: FAIL because `LidStateMonitoring`, `LidState`, `LidSoundPlaying`, and `LidEventSoundController` do not exist.

- [x] **Step 3: Implement lid event sound policy**

Create `Sources/CocaineCore/LidEventSoundController.swift`:

```swift
import Combine
import Foundation

public enum LidState: Equatable, Sendable {
    case open
    case closed
}

public protocol LidStateMonitoring: AnyObject {
    var onLidStateChange: (@MainActor (LidState) -> Void)? { get set }
    var isMonitoring: Bool { get }
    func start() throws
    func stop()
}

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
    private var cancellable: AnyCancellable?
    private var lastHandledState: LidState?
    private var monitoringStarted = false

    public init(
        state: AppState,
        monitor: LidStateMonitoring,
        soundPlayer: LidSoundPlaying
    ) {
        self.state = state
        self.monitor = monitor
        self.soundPlayer = soundPlayer

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

        switch lidState {
        case .closed:
            soundPlayer.play(named: Self.closeSoundName)
        case .open:
            soundPlayer.play(named: Self.openSoundName)
        }

        lastHandledState = lidState
    }
}
```

- [x] **Step 4: Run policy tests to verify they pass**

Run:

```bash
swift test --filter LidEventSoundControllerTests
```

Expected: PASS.

- [x] **Step 5: Run the full test suite**

Run:

```bash
swift test
```

Expected: PASS for all existing and new tests.

- [x] **Step 6: Commit policy layer**

Run:

```bash
git add Sources/CocaineCore/LidEventSoundController.swift Tests/CocaineCoreTests/LidEventSoundControllerTests.swift
git commit -m "feat: add lid event sound policy"
```

Expected: commit succeeds.

---

### Task 2: Passive IOKit Lid State Monitor

**Files:**
- Create: `Tests/CocaineCoreTests/LidStateMonitorTests.swift`
- Create: `Sources/CocaineCore/LidStateMonitor.swift`

- [x] **Step 1: Write failing lid monitor decoding tests**

Create `Tests/CocaineCoreTests/LidStateMonitorTests.swift`:

```swift
import XCTest
@testable import CocaineCore

final class LidStateMonitorTests: XCTestCase {
    func testClamshellArgumentWithoutStateBitMeansOpen() {
        XCTAssertEqual(
            LidStateMonitor.lidState(fromClamshellMessageArgument: 0),
            .open
        )
    }

    func testClamshellArgumentWithStateBitMeansClosed() {
        XCTAssertEqual(
            LidStateMonitor.lidState(fromClamshellMessageArgument: LidStateMonitor.clamshellStateBit),
            .closed
        )
    }

    func testClamshellArgumentIgnoresSleepBitForOpenClosedMapping() {
        let sleepBitOnly = UInt(1 << 1)
        let closedWithSleepBit = LidStateMonitor.clamshellStateBit | sleepBitOnly

        XCTAssertEqual(
            LidStateMonitor.lidState(fromClamshellMessageArgument: sleepBitOnly),
            .open
        )
        XCTAssertEqual(
            LidStateMonitor.lidState(fromClamshellMessageArgument: closedWithSleepBit),
            .closed
        )
    }

    func testClamshellStateChangeMessageMatchesIOKitMacroFormula() {
        let sysIOKit = UInt32(0x38 << 26)
        let subIOKitPowerManagement = UInt32(13 << 14)
        let clamshellMessage = UInt32(0x100)

        XCTAssertEqual(
            LidStateMonitor.clamshellStateChangeMessage,
            sysIOKit | subIOKitPowerManagement | clamshellMessage
        )
    }
}
```

- [x] **Step 2: Run lid monitor tests to verify they fail**

Run:

```bash
swift test --filter LidStateMonitorTests
```

Expected: FAIL because `LidStateMonitor` does not exist.

- [x] **Step 3: Implement passive IOKit monitor**

Create `Sources/CocaineCore/LidStateMonitor.swift`:

```swift
import Foundation
import IOKit

public enum LidStateMonitorError: Error, LocalizedError, Equatable {
    case rootDomainUnavailable
    case notificationPortUnavailable
    case runLoopSourceUnavailable
    case interestNotificationFailed(kern_return_t)

    public var errorDescription: String? {
        switch self {
        case .rootDomainUnavailable:
            return "IOPM root domain is unavailable"
        case .notificationPortUnavailable:
            return "Could not create lid-state notification port"
        case .runLoopSourceUnavailable:
            return "Could not create lid-state run loop source"
        case let .interestNotificationFailed(code):
            return "Could not register lid-state notifications: IOReturn \(code)"
        }
    }
}

public final class LidStateMonitor: LidStateMonitoring {
    nonisolated static let clamshellStateChangeMessage: UInt32 = (0x38 << 26) | (13 << 14) | 0x100
    nonisolated static let clamshellStateBit: UInt = 1 << 0

    public var onLidStateChange: (@MainActor (LidState) -> Void)?
    public private(set) var isMonitoring = false

    private var rootDomain: io_service_t = 0
    private var notificationPort: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private var runLoopSource: CFRunLoopSource?

    public init() {}

    deinit {
        stop()
    }

    public func start() throws {
        guard !isMonitoring else { return }

        let root = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPMrootDomain")
        )
        guard root != 0 else {
            throw LidStateMonitorError.rootDomainUnavailable
        }

        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            IOObjectRelease(root)
            throw LidStateMonitorError.notificationPortUnavailable
        }

        guard let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() else {
            IOObjectRelease(root)
            IONotificationPortDestroy(port)
            throw LidStateMonitorError.runLoopSourceUnavailable
        }

        var localNotifier = io_object_t()
        let result = IOServiceAddInterestNotification(
            port,
            root,
            kIOGeneralInterest,
            LidStateMonitor.handleInterestNotification,
            Unmanaged.passUnretained(self).toOpaque(),
            &localNotifier
        )

        guard result == KERN_SUCCESS else {
            IOObjectRelease(root)
            IONotificationPortDestroy(port)
            throw LidStateMonitorError.interestNotificationFailed(result)
        }

        rootDomain = root
        notificationPort = port
        notifier = localNotifier
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        isMonitoring = true
    }

    public func stop() {
        guard isMonitoring else { return }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }

        if notifier != 0 {
            IOObjectRelease(notifier)
            notifier = 0
        }

        if rootDomain != 0 {
            IOObjectRelease(rootDomain)
            rootDomain = 0
        }

        if let port = notificationPort {
            IONotificationPortDestroy(port)
            notificationPort = nil
        }

        isMonitoring = false
    }

    nonisolated static func lidState(fromClamshellMessageArgument messageArgument: UInt) -> LidState {
        (messageArgument & clamshellStateBit) == 0 ? .open : .closed
    }

    private static let handleInterestNotification: IOServiceInterestCallback = { refcon, _, messageType, messageArgument in
        guard messageType == LidStateMonitor.clamshellStateChangeMessage,
              let refcon else { return }

        let monitor = Unmanaged<LidStateMonitor>.fromOpaque(refcon).takeUnretainedValue()
        let argument = UInt(bitPattern: messageArgument)
        let lidState = LidStateMonitor.lidState(fromClamshellMessageArgument: argument)

        Task { @MainActor in
            monitor.onLidStateChange?(lidState)
        }
    }
}
```

- [x] **Step 4: Run lid monitor tests to verify they pass**

Run:

```bash
swift test --filter LidStateMonitorTests
```

Expected: PASS.

- [x] **Step 5: Run policy and monitor tests together**

Run:

```bash
swift test --filter 'Lid(EventSoundController|StateMonitor)Tests'
```

Expected: PASS for both lid sound test suites.

- [x] **Step 6: Run the full test suite**

Run:

```bash
swift test
```

Expected: PASS.

- [x] **Step 7: Commit passive lid monitor**

Run:

```bash
git add Sources/CocaineCore/LidStateMonitor.swift Tests/CocaineCoreTests/LidStateMonitorTests.swift
git commit -m "feat: monitor lid state changes"
```

Expected: commit succeeds.

---

### Task 3: AppKit Sound Playback and App Wiring

**Files:**
- Create: `Sources/Cocaine/SystemSoundPlayer.swift`
- Modify: `Sources/Cocaine/AppDelegate.swift`

- [x] **Step 1: Wire lid sounds in the app delegate before adding the sound player**

Modify `Sources/Cocaine/AppDelegate.swift` to this exact content:

```swift
import AppKit
import CocaineCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var coordinator: AppCoordinator?
    private var lidEventSoundController: LidEventSoundController?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        let awake = AwakeController()
        let lidClose = LidCloseController()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lidClose)
        let lidStateMonitor = LidStateMonitor()
        let soundPlayer = SystemSoundPlayer()

        self.coordinator = coordinator
        self.lidEventSoundController = LidEventSoundController(
            state: state,
            monitor: lidStateMonitor,
            soundPlayer: soundPlayer
        )
        self.menuBarController = MenuBarController(state: state, coordinator: coordinator)
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

- [x] **Step 2: Run app build to verify the missing sound player failure**

Run:

```bash
swift build
```

Expected: FAIL because `SystemSoundPlayer` does not exist.

- [x] **Step 3: Add the AppKit sound player wrapper**

Create `Sources/Cocaine/SystemSoundPlayer.swift`:

```swift
import AppKit
import CocaineCore

final class SystemSoundPlayer: LidSoundPlaying {
    func play(named soundName: String) {
        NSSound(named: NSSound.Name(soundName))?.play()
    }
}
```

- [x] **Step 4: Run app build to verify wiring compiles**

Run:

```bash
swift build
```

Expected: PASS.

- [x] **Step 5: Run full automated tests**

Run:

```bash
swift test
```

Expected: PASS.

- [x] **Step 6: Build the signed app bundle**

Run:

```bash
make app
```

Expected: PASS and `build/Cocaine.app` is created.

- [x] **Step 7: Commit app wiring**

Run:

```bash
git add Sources/Cocaine/AppDelegate.swift Sources/Cocaine/SystemSoundPlayer.swift
git commit -m "feat: wire lid event sounds"
```

Expected: commit succeeds.

---

### Task 4: User-Facing Documentation

**Files:**
- Modify: `README.md`

- [x] **Step 1: Update README behavior text**

Modify `README.md` to this exact content:

```markdown
# Cocaine

Personal macOS menu bar app with one on/off icon. When on, it prevents ordinary sleep and lid-close sleep. When off, it restores normal sleep behavior.

## Safety

Do not put a closed MacBook into a bag while Cocaine is on. Lid-close sleep prevention can leave the machine running and may cause overheating.

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

The first activation may request admin authorization to install the privileged helper.

## Behavior

- Left-click menu bar icon: toggle off/on.
- Off: normal sleep behavior and no lid event sounds.
- On: ordinary sleep and lid-close sleep are prevented.
- On, lid closes: plays the built-in macOS Hero sound.
- On, lid opens: plays the built-in macOS Basso sound.
- Right-click menu: About, helper repair when needed, Quit.
```

- [x] **Step 2: Run documentation diff review**

Run:

```bash
git diff -- README.md
```

Expected: diff only documents the new lid event sound behavior.

- [x] **Step 3: Commit README update**

Run:

```bash
git add README.md
git commit -m "docs: document lid event sounds"
```

Expected: commit succeeds.

---

### Task 5: Final Verification and Manual Validation Notes

**Files:**
- Modify: `docs/feat/20260425200131-lid-event-sounds/context.md`

- [x] **Step 1: Run clean automated verification**

Run:

```bash
make clean && make test && make app
```

Expected: PASS. `make test` runs all XCTest coverage, and `make app` creates the signed app bundle.

- [x] **Step 2: Confirm built-in sound names still resolve**

Run:

```bash
for sound in Hero Basso; do test -f "/System/Library/Sounds/${sound}.aiff" && echo "${sound}: ok"; done
```

Expected output:

```text
Hero: ok
Basso: ok
```

- [x] **Step 3: Perform MacBook manual validation**

Run the app:

```bash
make run
```

Manual checks:

1. Activate Cocaine from the menu bar icon.
2. Close the MacBook lid while near the machine.
3. Expected: Hero plays once.
4. Open the lid.
5. Expected: Basso plays once.
6. Close and open again.
7. Expected: Hero and Basso each play once per real transition.
8. Turn Cocaine off.
9. Close or open the lid.
10. Expected: no Cocaine lid event sound is played while off.

- [x] **Step 4: Append verification result to task memory**

Update `docs/feat/20260425200131-lid-event-sounds/context.md` by appending this log entry. If manual validation cannot be completed in the current environment, replace the manual-validation clause in the `How` bullet with `manual MacBook validation remains pending` rather than claiming it passed:

```markdown
### 2026-04-25 HH:MM — Lid event sounds implemented

- Why: The approved feature needed audible close/open feedback while lid-close prevention is active.
- How: Added testable lid sound policy, passive IOKit lid state monitoring, AppKit built-in sound playback, app lifecycle wiring, and README behavior docs. Verified with `make clean && make test && make app`; manual MacBook validation confirmed Hero on close and Basso on open while active, with no sound while off.
- Decision: Kept sound monitoring app-side and auxiliary; helper behavior and sleep-prevention rollback paths remain unchanged.
```

- [x] **Step 5: Commit task memory update**

Run:

```bash
git add docs/feat/20260425200131-lid-event-sounds/context.md
git commit -m "docs: record lid sound verification"
```

Expected: commit succeeds.
