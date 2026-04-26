# Lid Behavior Refinements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine Cocaine's menu and lid/display settings so the main keep-awake feature stays intact, checkboxes stay open while toggled, lid sounds depend on lid-close prevention, forced lock UI is removed, helper repair UI is removed, and Launch at Login is exposed.

**Architecture:** Keep `AppCoordinator` as the sleep-prevention source of truth. Remove the active lock-screen responder path, gate sound playback in `LidEventSoundController`, add a small testable `LaunchAtLoginController` around `SMAppService`, and refactor `MenuBarController` to build custom checkbox row views for preferences.

**Tech Stack:** Swift 5.9, SwiftPM, AppKit, Combine, ServiceManagement, XCTest, UserDefaults, IOKit power assertions.

---

## File Structure

- `Sources/CocaineCore/LidEventSoundController.swift` — keep monitoring/sound ownership; add `preventLidCloseSleep` gate before playback.
- `Sources/CocaineCore/LaunchAtLoginController.swift` — new testable controller and service abstraction for `SMAppService.mainApp`.
- `Sources/CocaineCore/ScreenLocker.swift` — delete; forced screen locking is no longer a product behavior.
- `Sources/CocaineCore/LidCloseLockResponder.swift` — delete; forced lid-close locking is no longer a product behavior.
- `Sources/Cocaine/AppDelegate.swift` — unwire deleted lock components; wire `LaunchAtLoginController` into menu controller.
- `Sources/Cocaine/MenuBarController.swift` — remove lock and repair menu rows; add launch-at-login row; switch preference rows to custom views; disable sound row when lid-close prevention is off.
- `Sources/Cocaine/CheckboxMenuItemView.swift` — new focused AppKit view for a checkbox menu row whose click does not dismiss the menu.
- `Tests/CocaineCoreTests/LidEventSoundControllerTests.swift` — update sound tests for lid-close dependency.
- `Tests/CocaineCoreTests/LaunchAtLoginControllerTests.swift` — new tests for launch-at-login status and toggling.
- `Tests/CocaineCoreTests/LidCloseLockResponderTests.swift` — delete with removed feature.
- `README.md` — update visible behavior table and native macOS lock explanation.
- `docs/feat/20260426083000-lid-behavior-refinements/context.md` — record implementation progress.

---

## Task 1: Remove forced lock-screen feature wiring

**Files:**
- Modify: `Sources/Cocaine/AppDelegate.swift`
- Delete: `Sources/CocaineCore/ScreenLocker.swift`
- Delete: `Sources/CocaineCore/LidCloseLockResponder.swift`
- Delete: `Tests/CocaineCoreTests/LidCloseLockResponderTests.swift`

- [x] **Step 1: Run the focused test that currently covers the feature being removed**

Run:

```bash
swift test --filter LidCloseLockResponderTests
```

Expected before deletion: PASS. This confirms the soon-to-be-removed forced lock path is currently represented by tests.

- [x] **Step 2: Unwire the lock responder from the app delegate**

Replace the contents of `Sources/Cocaine/AppDelegate.swift` with:

```swift
import AppKit
import CocaineCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var preferences: PreferencesStore?
    private var menuBarController: MenuBarController?
    private var coordinator: AppCoordinator?
    private var lidEventSoundController: LidEventSoundController?

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

        let lidEventSoundController = LidEventSoundController(
            state: state,
            monitor: lidStateMonitor,
            soundPlayer: soundPlayer,
            preferences: preferences
        )

        self.preferences = preferences
        self.coordinator = coordinator
        self.lidEventSoundController = lidEventSoundController
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

- [x] **Step 3: Delete forced-lock source files and tests**

Run:

```bash
rm Sources/CocaineCore/ScreenLocker.swift Sources/CocaineCore/LidCloseLockResponder.swift Tests/CocaineCoreTests/LidCloseLockResponderTests.swift
```

Expected: files are removed locally.

- [x] **Step 4: Verify no production code references the deleted feature**

Run:

```bash
rg -n "LidCloseLockResponder|ScreenLocker|ScreenLocking|LoginFrameworkScreenLocker" Sources Tests
```

Expected: no output.

- [x] **Step 5: Verify the package still builds after deleting forced-lock files**

Run:

```bash
swift build
```

Expected: build succeeds.

- [x] **Step 6: Commit Task 1**

```bash
git add Sources/Cocaine/AppDelegate.swift Sources/CocaineCore/ScreenLocker.swift Sources/CocaineCore/LidCloseLockResponder.swift Tests/CocaineCoreTests/LidCloseLockResponderTests.swift
git commit -m "refactor: remove forced lid-close locking"
```

---

## Task 2: Gate lid event sounds on lid-close prevention

**Files:**
- Modify: `Sources/CocaineCore/LidEventSoundController.swift`
- Modify: `Tests/CocaineCoreTests/LidEventSoundControllerTests.swift`

- [ ] **Step 1: Add the failing regression test**

In `Tests/CocaineCoreTests/LidEventSoundControllerTests.swift`, add this test inside `final class LidEventSoundControllerTests`:

```swift
func testPreventLidCloseSleepOffSilencesEventsEvenWhenSoundsEnabled() {
    let state = AppState(isActive: true)
    let monitor = FakeLidStateMonitor()
    let player = FakeLidSoundPlayer()
    let prefs = FakePreferencesStore()
    prefs.preventLidCloseSleep = false
    prefs.playLidEventSounds = true
    let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: prefs)

    monitor.emit(.closed)
    monitor.emit(.open)

    XCTAssertTrue(player.playedSoundNames.isEmpty)
    _ = controller
}
```

- [ ] **Step 2: Update existing sound-positive tests to express the required lid-close state**

For each test that expects `"Hero"` or `"Basso"` playback, create a preferences fake, set `preventLidCloseSleep = true`, and pass it into the controller. For example, change `testCloseEventWhileActivePlaysHero` to:

```swift
func testCloseEventWhileActivePlaysHero() {
    let state = AppState(isActive: true)
    let monitor = FakeLidStateMonitor()
    let player = FakeLidSoundPlayer()
    let prefs = FakePreferencesStore()
    prefs.preventLidCloseSleep = true
    let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: prefs)

    monitor.emit(.closed)

    XCTAssertEqual(player.playedSoundNames, ["Hero"])
    _ = controller
}
```

Apply the same `prefs.preventLidCloseSleep = true` setup to:

- `testOpenEventWhileActivePlaysBasso`
- `testDuplicateLidStatesDoNotReplaySounds`
- `testDeactivationStopsMonitoringAndClearsDuplicateState`
- `testPlayLidEventSoundsOffSilencesBothEvents`
- `testTogglingPlayLidEventSoundsBetweenEventsAffectsOnlyNextEvent`
- `testMutedDuplicateLidStateDoesNotReplayAfterSoundsReenabled`

- [ ] **Step 3: Run the focused test and verify the new test fails**

Run:

```bash
swift test --filter LidEventSoundControllerTests/testPreventLidCloseSleepOffSilencesEventsEvenWhenSoundsEnabled
```

Expected before implementation: FAIL because the controller currently checks only `playLidEventSounds`.

- [ ] **Step 4: Implement the lid-close-prevention gate**

In `Sources/CocaineCore/LidEventSoundController.swift`, replace the `handle(_:)` method with:

```swift
private func handle(_ lidState: LidState) {
    guard state.isActive, monitoringStarted, lidState != lastHandledState else { return }
    lastHandledState = lidState

    guard preferences.preventLidCloseSleep, preferences.playLidEventSounds else { return }

    switch lidState {
    case .closed:
        soundPlayer.play(named: Self.closeSoundName)
    case .open:
        soundPlayer.play(named: Self.openSoundName)
    }
}
```

The assignment to `lastHandledState` remains before the preference gates to preserve duplicate suppression for muted or disabled events.

- [ ] **Step 5: Run the sound-controller tests**

Run:

```bash
swift test --filter LidEventSoundControllerTests
```

Expected: all `LidEventSoundControllerTests` pass.

- [ ] **Step 6: Commit Task 2**

```bash
git add Sources/CocaineCore/LidEventSoundController.swift Tests/CocaineCoreTests/LidEventSoundControllerTests.swift
git commit -m "fix: gate lid sounds on lid-close prevention"
```

---

## Task 3: Add testable Launch at Login controller

**Files:**
- Create: `Sources/CocaineCore/LaunchAtLoginController.swift`
- Create: `Tests/CocaineCoreTests/LaunchAtLoginControllerTests.swift`

- [ ] **Step 1: Write failing launch-at-login tests**

Create `Tests/CocaineCoreTests/LaunchAtLoginControllerTests.swift` with:

```swift
import XCTest
@testable import CocaineCore

@MainActor
private final class FakeLoginItemService: LoginItemServicing {
    var status: LaunchAtLoginStatus = .disabled
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    func register() throws {
        registerCallCount += 1
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError { throw unregisterError }
        status = .disabled
    }
}

private struct LaunchAtLoginTestError: Error, LocalizedError {
    let errorDescription: String?
}

@MainActor
final class LaunchAtLoginControllerTests: XCTestCase {
    func testIsEnabledReflectsServiceStatus() {
        let service = FakeLoginItemService()
        let controller = LaunchAtLoginController(service: service)

        service.status = .disabled
        XCTAssertFalse(controller.isEnabled)

        service.status = .enabled
        XCTAssertTrue(controller.isEnabled)

        service.status = .requiresApproval
        XCTAssertFalse(controller.isEnabled)

        service.status = .unavailable
        XCTAssertFalse(controller.isEnabled)
    }

    func testSetEnabledRegistersWhenCurrentlyDisabled() throws {
        let service = FakeLoginItemService()
        service.status = .disabled
        let controller = LaunchAtLoginController(service: service)

        try controller.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(service.status, .enabled)
        XCTAssertTrue(controller.isEnabled)
    }

    func testSetEnabledDoesNothingWhenAlreadyEnabled() throws {
        let service = FakeLoginItemService()
        service.status = .enabled
        let controller = LaunchAtLoginController(service: service)

        try controller.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertTrue(controller.isEnabled)
    }

    func testSetDisabledUnregistersWhenEnabled() throws {
        let service = FakeLoginItemService()
        service.status = .enabled
        let controller = LaunchAtLoginController(service: service)

        try controller.setEnabled(false)

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(service.status, .disabled)
        XCTAssertFalse(controller.isEnabled)
    }

    func testSetDisabledUnregistersWhenRequiresApproval() throws {
        let service = FakeLoginItemService()
        service.status = .requiresApproval
        let controller = LaunchAtLoginController(service: service)

        try controller.setEnabled(false)

        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(service.status, .disabled)
        XCTAssertFalse(controller.isEnabled)
    }

    func testRegisterFailurePropagatesAndLeavesStatusUnchanged() {
        let service = FakeLoginItemService()
        service.status = .disabled
        service.registerError = LaunchAtLoginTestError(errorDescription: "registration failed")
        let controller = LaunchAtLoginController(service: service)

        XCTAssertThrowsError(try controller.setEnabled(true)) { error in
            XCTAssertEqual(error.localizedDescription, "registration failed")
        }

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertFalse(controller.isEnabled)
    }

    func testUnregisterFailurePropagatesAndLeavesStatusUnchanged() {
        let service = FakeLoginItemService()
        service.status = .enabled
        service.unregisterError = LaunchAtLoginTestError(errorDescription: "unregistration failed")
        let controller = LaunchAtLoginController(service: service)

        XCTAssertThrowsError(try controller.setEnabled(false)) { error in
            XCTAssertEqual(error.localizedDescription, "unregistration failed")
        }

        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertTrue(controller.isEnabled)
    }
}
```

- [ ] **Step 2: Run the new tests and verify they fail to compile**

Run:

```bash
swift test --filter LaunchAtLoginControllerTests
```

Expected before implementation: FAIL to compile because `LaunchAtLoginController`, `LoginItemServicing`, and `LaunchAtLoginStatus` do not exist.

- [ ] **Step 3: Add the launch-at-login controller**

Create `Sources/CocaineCore/LaunchAtLoginController.swift` with:

```swift
import Foundation
import ServiceManagement

public enum LaunchAtLoginStatus: Equatable, Sendable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    init(serviceManagementStatus: SMAppService.Status) {
        switch serviceManagementStatus {
        case .enabled:
            self = .enabled
        case .notRegistered:
            self = .disabled
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .unavailable
        @unknown default:
            self = .unavailable
        }
    }
}

@MainActor
public protocol LoginItemServicing: AnyObject {
    var status: LaunchAtLoginStatus { get }
    func register() throws
    func unregister() throws
}

@MainActor
public final class MainAppLoginItemService: LoginItemServicing {
    public init() {}

    public var status: LaunchAtLoginStatus {
        LaunchAtLoginStatus(serviceManagementStatus: SMAppService.mainApp.status)
    }

    public func register() throws {
        try SMAppService.mainApp.register()
    }

    public func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

@MainActor
public protocol LaunchAtLoginControlling: AnyObject {
    var isEnabled: Bool { get }
    var status: LaunchAtLoginStatus { get }
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
public final class LaunchAtLoginController: LaunchAtLoginControlling {
    private let service: LoginItemServicing

    public init(service: LoginItemServicing = MainAppLoginItemService()) {
        self.service = service
    }

    public var status: LaunchAtLoginStatus {
        service.status
    }

    public var isEnabled: Bool {
        service.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard service.status != .enabled else { return }
            try service.register()
            return
        }

        switch service.status {
        case .enabled, .requiresApproval:
            try service.unregister()
        case .disabled, .unavailable:
            return
        }
    }
}
```

- [ ] **Step 4: Run launch-at-login tests**

Run:

```bash
swift test --filter LaunchAtLoginControllerTests
```

Expected: all `LaunchAtLoginControllerTests` pass.

- [ ] **Step 5: Commit Task 3**

```bash
git add Sources/CocaineCore/LaunchAtLoginController.swift Tests/CocaineCoreTests/LaunchAtLoginControllerTests.swift
git commit -m "feat: add launch at login controller"
```

---

## Task 4: Refactor menu checkboxes to stay open and match the new menu

**Files:**
- Create: `Sources/Cocaine/CheckboxMenuItemView.swift`
- Modify: `Sources/Cocaine/MenuBarController.swift`
- Modify: `Sources/Cocaine/AppDelegate.swift`

- [ ] **Step 1: Add the custom checkbox row view**

Create `Sources/Cocaine/CheckboxMenuItemView.swift` with:

```swift
import AppKit

@MainActor
final class CheckboxMenuItemView: NSView {
    private enum Metrics {
        static let width: CGFloat = 240
        static let height: CGFloat = 24
        static let leadingPadding: CGFloat = 14
        static let trailingPadding: CGFloat = 8
    }

    private let checkbox: NSButton
    var onToggle: (() -> Void)?

    init(title: String, isOn: Bool, isEnabled: Bool = true) {
        self.checkbox = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        super.init(frame: NSRect(x: 0, y: 0, width: Metrics.width, height: Metrics.height))

        checkbox.target = self
        checkbox.action = #selector(toggle)
        checkbox.state = isOn ? .on : .off
        checkbox.isEnabled = isEnabled
        checkbox.translatesAutoresizingMaskIntoConstraints = false

        addSubview(checkbox)

        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.leadingPadding),
            checkbox.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Metrics.trailingPadding),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(title: String, isOn: Bool, isEnabled: Bool) {
        checkbox.title = title
        checkbox.state = isOn ? .on : .off
        checkbox.isEnabled = isEnabled
    }

    @objc
    private func toggle() {
        onToggle?()
    }
}
```

- [ ] **Step 2: Replace `MenuBarController` with the new menu implementation**

Replace `Sources/Cocaine/MenuBarController.swift` with:

```swift
import AppKit
import Combine
import CocaineCore

@MainActor
final class MenuBarController: NSObject {
    private enum PreferenceRowID: Hashable {
        case preventDisplaySleep
        case preventLidCloseSleep
        case playLidEventSounds
        case launchAtLogin
    }

    private let state: AppState
    private let coordinator: AppCoordinator
    private let preferences: PreferencesStore
    private let launchAtLoginController: LaunchAtLoginControlling
    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []
    private var visibleRows: [PreferenceRowID: CheckboxMenuItemView] = [:]
    private var launchAtLoginErrorMessage: String?

    init(
        state: AppState,
        coordinator: AppCoordinator,
        preferences: PreferencesStore,
        launchAtLoginController: LaunchAtLoginControlling
    ) {
        self.state = state
        self.coordinator = coordinator
        self.preferences = preferences
        self.launchAtLoginController = launchAtLoginController
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
        preferences.preventLidCloseSleepPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.render()
                self?.refreshVisibleRows()
            }
            .store(in: &cancellables)
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
        visibleRows = [:]

        if let error = state.lastErrorMessage {
            let errorItem = NSMenuItem(title: "Error: \(error)", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
            menu.addItem(NSMenuItem.separator())
        }

        if let launchAtLoginErrorMessage {
            let errorItem = NSMenuItem(title: "Login item error: \(launchAtLoginErrorMessage)", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
            menu.addItem(NSMenuItem.separator())
        }

        let aboutItem = NSMenuItem(title: "About Cocaine", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        addCheckboxRow(
            to: menu,
            id: .preventDisplaySleep,
            title: "Prevent display sleep",
            isOn: preferences.preventDisplaySleep,
            isEnabled: true
        ) { [weak self] in
            self?.togglePreventDisplaySleep()
        }

        addCheckboxRow(
            to: menu,
            id: .preventLidCloseSleep,
            title: lidCloseTitle,
            isOn: preferences.preventLidCloseSleep,
            isEnabled: true
        ) { [weak self] in
            self?.togglePreventLidCloseSleep()
        }

        addCheckboxRow(
            to: menu,
            id: .playLidEventSounds,
            title: "Play lid event sounds",
            isOn: preferences.playLidEventSounds,
            isEnabled: preferences.preventLidCloseSleep
        ) { [weak self] in
            self?.togglePlayLidEventSounds()
        }

        addCheckboxRow(
            to: menu,
            id: .launchAtLogin,
            title: "Launch at login",
            isOn: launchAtLoginController.isEnabled,
            isEnabled: true
        ) { [weak self] in
            self?.toggleLaunchAtLogin()
        }

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
        visibleRows = [:]
    }

    private var lidCloseTitle: String {
        preferences.preventLidCloseSleep
            ? "⚠ Prevent sleep with lid closed"
            : "Prevent sleep with lid closed"
    }

    private func addCheckboxRow(
        to menu: NSMenu,
        id: PreferenceRowID,
        title: String,
        isOn: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) {
        let item = NSMenuItem()
        let row = CheckboxMenuItemView(title: title, isOn: isOn, isEnabled: isEnabled)
        row.onToggle = action
        item.view = row
        menu.addItem(item)
        visibleRows[id] = row
    }

    private func refreshVisibleRows() {
        visibleRows[.preventDisplaySleep]?.update(
            title: "Prevent display sleep",
            isOn: preferences.preventDisplaySleep,
            isEnabled: true
        )
        visibleRows[.preventLidCloseSleep]?.update(
            title: lidCloseTitle,
            isOn: preferences.preventLidCloseSleep,
            isEnabled: true
        )
        visibleRows[.playLidEventSounds]?.update(
            title: "Play lid event sounds",
            isOn: preferences.playLidEventSounds,
            isEnabled: preferences.preventLidCloseSleep
        )
        visibleRows[.launchAtLogin]?.update(
            title: "Launch at login",
            isOn: launchAtLoginController.isEnabled,
            isEnabled: true
        )
    }

    private func togglePreventDisplaySleep() {
        let newValue = !preferences.preventDisplaySleep
        Task { @MainActor in
            await coordinator.setPreventDisplaySleep(newValue)
            refreshVisibleRows()
        }
    }

    private func togglePreventLidCloseSleep() {
        let newValue = !preferences.preventLidCloseSleep
        if newValue && !preferences.lidClosePreventionConfirmed {
            guard confirmLidClosePreventionEnable() else {
                refreshVisibleRows()
                return
            }
            preferences.lidClosePreventionConfirmed = true
        }
        if !newValue {
            preferences.lidClosePreventionConfirmed = false
        }
        Task { @MainActor in
            await coordinator.setPreventLidCloseSleep(newValue)
            if newValue && !preferences.preventLidCloseSleep {
                preferences.lidClosePreventionConfirmed = false
            }
            refreshVisibleRows()
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

    private func togglePlayLidEventSounds() {
        guard preferences.preventLidCloseSleep else {
            refreshVisibleRows()
            return
        }
        preferences.playLidEventSounds.toggle()
        refreshVisibleRows()
    }

    private func toggleLaunchAtLogin() {
        do {
            try launchAtLoginController.setEnabled(!launchAtLoginController.isEnabled)
            launchAtLoginErrorMessage = nil
        } catch {
            launchAtLoginErrorMessage = error.localizedDescription
        }
        refreshVisibleRows()
    }

    @objc
    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: "Personal keep-awake utility inspired by Caffeine and Fermata."),
        ])
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 3: Wire the new launch-at-login controller in `AppDelegate`**

If Task 1 has not already changed `Sources/Cocaine/AppDelegate.swift`, update the `MenuBarController` construction to:

```swift
self.menuBarController = MenuBarController(
    state: state,
    coordinator: coordinator,
    preferences: preferences,
    launchAtLoginController: LaunchAtLoginController()
)
```

Also ensure these deleted lock lines are absent:

```swift
private var lidCloseLockResponder: LidCloseLockResponder?
let screenLocker = LoginFrameworkScreenLocker()
let lidCloseLockResponder = LidCloseLockResponder(
self.lidCloseLockResponder = lidCloseLockResponder
```

- [ ] **Step 4: Verify stale menu labels are gone**

Run:

```bash
rg -n "Lock screen when lid closes|Repair / Install Helper|toggleLockScreenOnLidClose|repairHelper" Sources/Cocaine Sources/CocaineCore
```

Expected: no output.

- [ ] **Step 5: Verify the app target builds**

Run:

```bash
swift build --product Cocaine
```

Expected: build succeeds.

- [ ] **Step 6: Commit Task 4**

```bash
git add Sources/Cocaine/CheckboxMenuItemView.swift Sources/Cocaine/MenuBarController.swift Sources/Cocaine/AppDelegate.swift
git commit -m "feat: keep preference menu open while toggling"
```

---

## Task 5: Update README behavior documentation

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace the README behavior table and stale lock/repair text**

In `README.md`, replace the current `## Behavior` section with:

```markdown
## Behavior

- **Left-click menu bar icon:** toggle Cocaine off ↔ on. While on, Cocaine prevents system sleep and enforces your current preferences.
- **Right-click menu bar icon:** opens a menu with checkbox preferences. Preference checkbox clicks keep the menu open so multiple settings can be changed quickly.

  | Preference | Default | What it does |
  |---|---|---|
  | Prevent display sleep | ON | Holds a display-sleep assertion in addition to the no-idle assertion. If off, the computer stays awake but the display may sleep and macOS lock-screen settings may apply. |
  | Prevent sleep with lid closed | OFF | Engages the privileged helper to keep the Mac awake when the lid closes. Requires one-time admin authorization and the existing safety confirmation. |
  | Play lid event sounds | ON | Plays the macOS Hero sound on lid close and Basso on lid open only while lid-close sleep prevention is enabled. The menu row is disabled when lid-close prevention is off. |
  | Launch at login | OFF | Registers Cocaine as a macOS login item. The checkbox reflects the actual system login-item state. |

- **When Cocaine is off:** all preferences are inert. No assertions are held and no helper calls are made.
- **When Cocaine is on and lid-close prevention is off:** closing the lid follows normal macOS behavior, including native sleep/lock behavior configured in System Settings.
- **When Cocaine is on and lid-close prevention is on:** the helper keeps the Mac awake with the lid closed. Do not put it in a bag in this state.
```

- [ ] **Step 2: Update the README summary**

Replace the opening paragraph under `# Cocaine` with:

```markdown
Personal macOS menu bar app with one on/off icon. When on, it prevents system sleep using public IOKit assertions. Optional preferences extend that to display sleep, lid-close sleep prevention, lid event sounds, and launching at login.
```

- [ ] **Step 3: Verify the README no longer advertises removed UI**

Run:

```bash
rg -n "Lock screen when lid closes|Repair / Install Helper|screen locking on lid close" README.md
```

Expected: no output.

- [ ] **Step 4: Commit Task 5**

```bash
git add README.md
git commit -m "docs: update lid refinement behavior"
```

---

## Task 6: Final verification and task record update

**Files:**
- Modify: `docs/feat/20260426083000-lid-behavior-refinements/context.md`

- [ ] **Step 1: Run full tests**

Run:

```bash
make test
```

Expected: all tests pass.

- [ ] **Step 2: Build the app bundle**

Run:

```bash
make app
```

Expected: `build/Cocaine.app` is created successfully.

- [ ] **Step 3: Run stale-reference checks**

Run:

```bash
rg -n "Lock screen when lid closes|Repair / Install Helper|LidCloseLockResponder|ScreenLocker|LoginFrameworkScreenLocker|toggleLockScreenOnLidClose|repairHelper" Sources Tests README.md docs/feat/20260426083000-lid-behavior-refinements
```

Expected: no stale production/test/doc references except historical text inside committed older `docs/feat/20260425232900-lid-behavior-settings/` if that wider path is searched.

- [ ] **Step 4: Manual app checks**

Launch `build/Cocaine.app` and verify:

1. Right-click menu opens.
2. Toggling `Prevent display sleep` does not close the menu.
3. Toggling `Prevent sleep with lid closed` does not close the menu after the confirmation alert is handled.
4. `Play lid event sounds` is visible but disabled when `Prevent sleep with lid closed` is off.
5. `Lock screen when lid closes` is absent.
6. `Repair / Install Helper` is absent.
7. `Launch at login` appears and reflects the system login-item state.
8. Left-click still toggles Cocaine's main keep-awake behavior.

- [ ] **Step 5: Update task record**

Append this log entry to `docs/feat/20260426083000-lid-behavior-refinements/context.md`, replacing the verification sentence with the actual test counts and commit hashes from the implementation session:

```markdown
### 2026-04-26 — Implementation complete

Implemented the approved lid behavior refinements: removed forced lock-screen UI and code path, removed helper repair menu item, gated lid sounds on lid-close prevention, added Launch at Login backed by actual macOS state, converted preference rows to non-dismissing checkbox views, and updated README behavior docs. Verified `make test` and `make app` passed. Manual menu checks completed: right-click menu remained open across preference toggles; sound row disabled when lid-close prevention was off; removed rows absent; launch-at-login row present.
```

- [ ] **Step 6: Commit Task 6**

```bash
git add docs/feat/20260426083000-lid-behavior-refinements/context.md
git commit -m "docs: record lid refinement implementation"
```
