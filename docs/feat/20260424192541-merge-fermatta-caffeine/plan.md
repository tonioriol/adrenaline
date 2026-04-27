# Insomnia Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app named Insomnia with one clickable off/on icon; on prevents ordinary sleep and lid-close sleep, off restores normal sleep behavior.

**Architecture:** Use a new SwiftPM-based codebase with a testable `InsomniaCore` library, an AppKit menu bar executable, and a small privileged helper executable. The app coordinator owns the one-toggle state machine; UI code only forwards clicks and renders state; privileged lid-close behavior is isolated behind a helper client and XPC protocol.

**Tech Stack:** Swift 5.9+, SwiftPM, XCTest, AppKit, Combine, IOKit power assertions, Foundation XPC, ServiceManagement `SMJobBless`, Makefile app bundling/signing.

---

## Scope Check

The approved spec contains one product surface: a single-toggle macOS keep-awake app. The privileged helper is a required implementation detail for the same user-facing behavior, so this stays one plan rather than separate specs.

## File Structure

- Create `Package.swift` — SwiftPM manifest with app, core, helper, and test targets.
- Create `Makefile` — build/test/package commands for the app bundle and privileged helper.
- Create `README.md` — local build/run/safety notes.
- Create `NOTICE.md` — upstream attribution for Caffeine and Fermata references.
- Create `Resources/Insomnia/Info.plist` — app bundle metadata and helper authorization requirement.
- Create `Resources/InsomniaHelper/Info.plist` — embedded helper metadata and authorized app requirement.
- Create `Resources/InsomniaHelper/launchd.plist` — helper launchd Mach service metadata.
- Create `Sources/Insomnia/main.swift` — app executable entry point.
- Create `Sources/Insomnia/AppDelegate.swift` — accessory app lifecycle bridge.
- Create `Sources/Insomnia/MenuBarController.swift` — `NSStatusItem`, click handling, minimal menu, icons.
- Create `Sources/InsomniaCore/AppState.swift` — observable user-facing state.
- Create `Sources/InsomniaCore/AppCoordinator.swift` — one-toggle orchestration and rollback.
- Create `Sources/InsomniaCore/AwakeController.swift` — ordinary sleep assertion owner.
- Create `Sources/InsomniaCore/PowerAssertionClient.swift` — IOKit assertion wrapper with fakeable protocol.
- Create `Sources/InsomniaCore/LidCloseController.swift` — lid-close enable/disable/status orchestration.
- Create `Sources/InsomniaCore/InsomniaHelperProtocol.swift` — shared XPC protocol and helper constants.
- Create `Sources/InsomniaCore/PrivilegedHelperClient.swift` — helper install, XPC connection, async wrappers.
- Create `Sources/InsomniaHelper/ApplePowerSettings.swift` — private power setting bridge isolated to helper.
- Create `Sources/InsomniaHelper/main.swift` — helper XPC listener implementation.
- Create `Tests/InsomniaCoreTests/AppStateTests.swift` — state defaults and transitions.
- Create `Tests/InsomniaCoreTests/AppCoordinatorTests.swift` — toggle success/failure/rollback tests.
- Create `Tests/InsomniaCoreTests/AwakeControllerTests.swift` — assertion create/release tests.
- Create `Tests/InsomniaCoreTests/LidCloseControllerTests.swift` — helper delegation/status tests.

---

### Task 1: Project Skeleton and State Model

**Files:**
- Create: `Package.swift`
- Create: `Makefile`
- Create: `Sources/InsomniaCore/AppState.swift`
- Create: `Tests/InsomniaCoreTests/AppStateTests.swift`

- [x] **Step 1: Write the failing state tests**

Create `Tests/InsomniaCoreTests/AppStateTests.swift`:

```swift
import XCTest
@testable import InsomniaCore

@MainActor
final class AppStateTests: XCTestCase {
    func testInitialStateIsInactiveAndIdle() {
        let state = AppState()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertNil(state.lastErrorMessage)
        XCTAssertEqual(state.helperState, .unknown)
    }

    func testMarkingActiveClearsPreviousError() {
        let state = AppState()

        state.recordError("boom")
        state.setActive(true)

        XCTAssertTrue(state.isActive)
        XCTAssertNil(state.lastErrorMessage)
    }

    func testRecordingErrorKeepsFeatureInactive() {
        let state = AppState()

        state.setActive(true)
        state.recordError("helper failed")

        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.lastErrorMessage, "helper failed")
    }
}
```

Run:

```bash
cd /Users/tr0n/Code/insomnia && swift test
```

Expected: FAIL because `Package.swift` and `AppState` do not exist yet.

- [x] **Step 2: Create the Swift package manifest**

Create `Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Insomnia",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Insomnia", targets: ["Insomnia"]),
        .executable(name: "InsomniaHelper", targets: ["InsomniaHelper"]),
        .library(name: "InsomniaCore", targets: ["InsomniaCore"]),
    ],
    targets: [
        .target(
            name: "InsomniaCore",
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .executableTarget(
            name: "Insomnia",
            dependencies: ["InsomniaCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Foundation"),
            ]
        ),
        .executableTarget(
            name: "InsomniaHelper",
            dependencies: ["InsomniaCore"],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("IOKit"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/InsomniaHelper/Info.plist",
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__launchd_plist",
                    "-Xlinker", "Resources/InsomniaHelper/launchd.plist",
                ]),
            ]
        ),
        .testTarget(
            name: "InsomniaCoreTests",
            dependencies: ["InsomniaCore"]
        ),
    ]
)
```

- [x] **Step 3: Create the state model implementation**

Create `Sources/InsomniaCore/AppState.swift`:

```swift
import Combine
import Foundation

public enum HelperState: Equatable, Sendable {
    case unknown
    case notInstalled
    case installing
    case ready(version: Int)
    case failed(message: String)
}

@MainActor
public final class AppState: ObservableObject {
    @Published public private(set) var isActive: Bool
    @Published public private(set) var isBusy: Bool
    @Published public private(set) var helperState: HelperState
    @Published public private(set) var lastErrorMessage: String?

    public init(
        isActive: Bool = false,
        isBusy: Bool = false,
        helperState: HelperState = .unknown,
        lastErrorMessage: String? = nil
    ) {
        self.isActive = isActive
        self.isBusy = isBusy
        self.helperState = helperState
        self.lastErrorMessage = lastErrorMessage
    }

    public func setBusy(_ value: Bool) {
        isBusy = value
    }

    public func setActive(_ value: Bool) {
        isActive = value
        if value {
            lastErrorMessage = nil
        }
    }

    public func setHelperState(_ value: HelperState) {
        helperState = value
    }

    public func recordError(_ message: String) {
        isActive = false
        isBusy = false
        lastErrorMessage = message
        helperState = .failed(message: message)
    }

    public func clearError() {
        lastErrorMessage = nil
    }
}
```

- [x] **Step 4: Add basic build commands**

Create `Makefile`:

```makefile
SHELL := /bin/zsh
CONFIGURATION ?= debug
SWIFT_BUILD_FLAGS := -c $(CONFIGURATION)

.PHONY: test build clean

test:
	swift test

build:
	swift build $(SWIFT_BUILD_FLAGS)

clean:
	rm -rf .build build
```

- [x] **Step 5: Run tests and commit**

Run:

```bash
cd /Users/tr0n/Code/insomnia && make test
```

Expected: PASS with 3 tests.

Commit:

```bash
cd /Users/tr0n/Code/insomnia && git init && git add Package.swift Makefile Sources Tests && git commit -m "feat: add core state model"
```

---

### Task 2: One-Toggle Coordinator

**Files:**
- Create: `Sources/InsomniaCore/AppCoordinator.swift`
- Create: `Tests/InsomniaCoreTests/AppCoordinatorTests.swift`

- [x] **Step 1: Write failing coordinator tests**

Create `Tests/InsomniaCoreTests/AppCoordinatorTests.swift`:

```swift
import XCTest
@testable import InsomniaCore

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
    func testToggleOnEnablesAwakeAndLidCloseBeforeMarkingActive() async {
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

    func testLidCloseFailureRollsBackAwakeAndLeavesStateOff() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        lid.enableError = TestError(errorDescription: "helper refused")
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid)

        await coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertEqual(awake.disableCallCount, 1)
        XCTAssertEqual(lid.disableCallCount, 1)
        XCTAssertEqual(state.lastErrorMessage, "helper refused")
    }

    func testFalseStatusAfterEnableRollsBack() async {
        let state = AppState()
        let awake = FakeAwakeController()
        let lid = FakeLidCloseController()
        lid.statusValue = false
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lid)

        await coordinator.toggle()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(awake.isEnabled)
        XCTAssertEqual(state.lastErrorMessage, "Lid-close prevention did not become active")
    }
}
```

Run:

```bash
cd /Users/tr0n/Code/insomnia && swift test --filter AppCoordinatorTests
```

Expected: FAIL because coordinator and protocols do not exist.

- [x] **Step 2: Implement coordinator and protocols**

Create `Sources/InsomniaCore/AppCoordinator.swift`:

```swift
import Foundation

public protocol AwakeControlling: AnyObject {
    func enable() throws
    func disable()
}

public protocol LidCloseControlling: AnyObject {
    func enable() async throws
    func disable() async throws
    func status() async throws -> Bool
}

public enum AppCoordinatorError: Error, LocalizedError, Equatable {
    case lidCloseStatusDidNotBecomeActive

    public var errorDescription: String? {
        switch self {
        case .lidCloseStatusDidNotBecomeActive:
            return "Lid-close prevention did not become active"
        }
    }
}

@MainActor
public final class AppCoordinator {
    private let state: AppState
    private let awakeController: AwakeControlling
    private let lidCloseController: LidCloseControlling

    public init(
        state: AppState,
        awakeController: AwakeControlling,
        lidCloseController: LidCloseControlling
    ) {
        self.state = state
        self.awakeController = awakeController
        self.lidCloseController = lidCloseController
    }

    public func toggle() async {
        if state.isActive {
            await turnOff()
        } else {
            await turnOn()
        }
    }

    public func turnOn() async {
        guard !state.isBusy else { return }
        state.setBusy(true)
        state.clearError()

        do {
            try awakeController.enable()
            try await lidCloseController.enable()

            guard try await lidCloseController.status() else {
                throw AppCoordinatorError.lidCloseStatusDidNotBecomeActive
            }

            state.setActive(true)
            state.setBusy(false)
        } catch {
            awakeController.disable()
            try? await lidCloseController.disable()
            state.recordError(error.localizedDescription)
        }
    }

    public func turnOff() async {
        guard !state.isBusy else { return }
        state.setBusy(true)
        awakeController.disable()

        do {
            try await lidCloseController.disable()
            _ = try? await lidCloseController.status()
            state.setActive(false)
            state.setBusy(false)
        } catch {
            state.setActive(false)
            state.setBusy(false)
            state.recordError(error.localizedDescription)
        }
    }
}
```

- [x] **Step 3: Run coordinator tests and commit**

Run:

```bash
cd /Users/tr0n/Code/insomnia && swift test --filter AppCoordinatorTests && make test
```

Expected: PASS.

Commit:

```bash
cd /Users/tr0n/Code/insomnia && git add Sources/InsomniaCore/AppCoordinator.swift Tests/InsomniaCoreTests/AppCoordinatorTests.swift && git commit -m "feat: add one-toggle coordinator"
```

---

### Task 3: Ordinary Sleep Prevention

**Files:**
- Create: `Sources/InsomniaCore/PowerAssertionClient.swift`
- Create: `Sources/InsomniaCore/AwakeController.swift`
- Create: `Tests/InsomniaCoreTests/AwakeControllerTests.swift`

- [x] **Step 1: Write failing ordinary assertion tests**

Create `Tests/InsomniaCoreTests/AwakeControllerTests.swift`:

```swift
import XCTest
@testable import InsomniaCore

private final class FakePowerAssertionClient: PowerAssertionClient {
    var nextID: UInt32 = 41
    var createdReasons: [String] = []
    var releasedIDs: [UInt32] = []
    var createError: Error?

    func createNoIdleSleepAssertion(reason: String) throws -> UInt32 {
        if let createError { throw createError }
        createdReasons.append(reason)
        nextID += 1
        return nextID
    }

    func createDisplaySleepAssertion(reason: String) throws -> UInt32 {
        if let createError { throw createError }
        createdReasons.append(reason)
        nextID += 1
        return nextID
    }

    func releaseAssertion(id: UInt32) {
        releasedIDs.append(id)
    }
}

@MainActor
final class AwakeControllerTests: XCTestCase {
    func testEnableCreatesSystemAndDisplayAssertions() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable()

        XCTAssertEqual(client.createdReasons, ["Insomnia is active", "Insomnia is active"])
        XCTAssertTrue(controller.isEnabled)
    }

    func testDisableReleasesCreatedAssertions() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable()
        controller.disable()

        XCTAssertEqual(client.releasedIDs, [42, 43])
        XCTAssertFalse(controller.isEnabled)
    }

    func testEnableIsIdempotent() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable()
        try controller.enable()

        XCTAssertEqual(client.createdReasons.count, 2)
        XCTAssertTrue(controller.isEnabled)
    }
}
```

Run:

```bash
cd /Users/tr0n/Code/insomnia && swift test --filter AwakeControllerTests
```

Expected: FAIL because `AwakeController` and `PowerAssertionClient` do not exist.

- [x] **Step 2: Implement IOKit assertion wrapper and awake controller**

Create `Sources/InsomniaCore/PowerAssertionClient.swift`:

```swift
import Foundation
import IOKit.pwr_mgt

public protocol PowerAssertionClient: AnyObject {
    func createNoIdleSleepAssertion(reason: String) throws -> UInt32
    func createDisplaySleepAssertion(reason: String) throws -> UInt32
    func releaseAssertion(id: UInt32)
}

public enum PowerAssertionError: Error, LocalizedError, Equatable {
    case creationFailed(type: String, code: IOReturn)

    public var errorDescription: String? {
        switch self {
        case let .creationFailed(type, code):
            return "Failed to create \(type) assertion: IOReturn \(code)"
        }
    }
}

public final class IOKitPowerAssertionClient: PowerAssertionClient {
    public init() {}

    public func createNoIdleSleepAssertion(reason: String) throws -> UInt32 {
        try createAssertion(type: kIOPMAssertionTypeNoIdleSleep as CFString, typeName: "no-idle-sleep", reason: reason)
    }

    public func createDisplaySleepAssertion(reason: String) throws -> UInt32 {
        try createAssertion(type: kIOPMAssertPreventUserIdleDisplaySleep as CFString, typeName: "display-sleep", reason: reason)
    }

    public func releaseAssertion(id: UInt32) {
        IOPMAssertionRelease(IOPMAssertionID(id))
    }

    private func createAssertion(type: CFString, typeName: String, reason: String) throws -> UInt32 {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(type, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &assertionID)
        guard result == kIOReturnSuccess else {
            throw PowerAssertionError.creationFailed(type: typeName, code: result)
        }
        return UInt32(assertionID)
    }
}
```

Create `Sources/InsomniaCore/AwakeController.swift`:

```swift
import Foundation

public final class AwakeController: AwakeControlling {
    private let client: PowerAssertionClient
    private var assertionIDs: [UInt32]

    public private(set) var isEnabled: Bool

    public init(client: PowerAssertionClient = IOKitPowerAssertionClient()) {
        self.client = client
        self.assertionIDs = []
        self.isEnabled = false
    }

    public func enable() throws {
        guard !isEnabled else { return }

        do {
            let systemID = try client.createNoIdleSleepAssertion(reason: "Insomnia is active")
            let displayID = try client.createDisplaySleepAssertion(reason: "Insomnia is active")
            assertionIDs = [systemID, displayID]
            isEnabled = true
        } catch {
            releaseAllAssertions()
            throw error
        }
    }

    public func disable() {
        releaseAllAssertions()
        isEnabled = false
    }

    private func releaseAllAssertions() {
        for id in assertionIDs {
            client.releaseAssertion(id: id)
        }
        assertionIDs.removeAll()
    }
}
```

- [x] **Step 3: Run tests and commit**

Run:

```bash
cd /Users/tr0n/Code/insomnia && swift test --filter AwakeControllerTests && make test
```

Expected: PASS.

Commit:

```bash
cd /Users/tr0n/Code/insomnia && git add Sources/InsomniaCore/PowerAssertionClient.swift Sources/InsomniaCore/AwakeController.swift Tests/InsomniaCoreTests/AwakeControllerTests.swift && git commit -m "feat: add ordinary sleep assertions"
```

---

### Task 4: Lid-Close Controller Contract

**Files:**
- Create: `Sources/InsomniaCore/InsomniaHelperProtocol.swift`
- Create: `Sources/InsomniaCore/LidCloseController.swift`
- Create: `Sources/InsomniaCore/PrivilegedHelperClient.swift`
- Create: `Tests/InsomniaCoreTests/LidCloseControllerTests.swift`

- [x] **Step 1: Write failing lid-close controller tests**

Create `Tests/InsomniaCoreTests/LidCloseControllerTests.swift`:

```swift
import XCTest
@testable import InsomniaCore

private final class FakePrivilegedHelperClient: PrivilegedHelperClientProtocol {
    var installed = false
    var enabled = false
    var installCallCount = 0
    var enableCallCount = 0
    var disableCallCount = 0
    var statusCallCount = 0
    var installError: Error?
    var enableError: Error?
    var disableError: Error?

    func installOrUpdateHelperIfNeeded() async throws {
        installCallCount += 1
        if let installError { throw installError }
        installed = true
    }

    func enableLidClosePrevention() async throws {
        enableCallCount += 1
        if let enableError { throw enableError }
        enabled = true
    }

    func disableLidClosePrevention() async throws {
        disableCallCount += 1
        if let disableError { throw disableError }
        enabled = false
    }

    func readLidClosePreventionStatus() async throws -> Bool {
        statusCallCount += 1
        return enabled
    }
}

@MainActor
final class LidCloseControllerTests: XCTestCase {
    func testEnableInstallsHelperThenEnablesLidClosePrevention() async throws {
        let helper = FakePrivilegedHelperClient()
        let controller = LidCloseController(helperClient: helper)

        try await controller.enable()

        XCTAssertTrue(helper.installed)
        XCTAssertTrue(helper.enabled)
        XCTAssertEqual(helper.installCallCount, 1)
        XCTAssertEqual(helper.enableCallCount, 1)
    }

    func testDisableForwardsToHelper() async throws {
        let helper = FakePrivilegedHelperClient()
        helper.enabled = true
        let controller = LidCloseController(helperClient: helper)

        try await controller.disable()

        XCTAssertFalse(helper.enabled)
        XCTAssertEqual(helper.disableCallCount, 1)
    }

    func testStatusForwardsToHelper() async throws {
        let helper = FakePrivilegedHelperClient()
        helper.enabled = true
        let controller = LidCloseController(helperClient: helper)

        let enabled = try await controller.status()

        XCTAssertTrue(enabled)
        XCTAssertEqual(helper.statusCallCount, 1)
    }
}
```

Run:

```bash
cd /Users/tr0n/Code/insomnia && swift test --filter LidCloseControllerTests
```

Expected: FAIL because lid-close controller types do not exist.

- [x] **Step 2: Implement helper protocol constants and controller with stub client**

Create `Sources/InsomniaCore/InsomniaHelperProtocol.swift`:

```swift
import Foundation

public enum InsomniaHelperConstants {
    public static let appBundleIdentifier = "com.tonioriol.insomnia"
    public static let helperBundleIdentifier = "com.tonioriol.insomnia.helper"
    public static let helperVersion = 1
}

@objc(InsomniaHelperProtocol)
public protocol InsomniaHelperProtocol {
    func enableLidClosePrevention(reply: @escaping (NSNumber, NSString?) -> Void)
    func disableLidClosePrevention(reply: @escaping (NSNumber, NSString?) -> Void)
    func readLidClosePreventionStatus(reply: @escaping (NSNumber, NSString?) -> Void)
    func helperVersion(reply: @escaping (NSNumber) -> Void)
}

public protocol PrivilegedHelperClientProtocol: AnyObject {
    func installOrUpdateHelperIfNeeded() async throws
    func enableLidClosePrevention() async throws
    func disableLidClosePrevention() async throws
    func readLidClosePreventionStatus() async throws -> Bool
}
```

Create `Sources/InsomniaCore/LidCloseController.swift`:

```swift
import Foundation

public final class LidCloseController: LidCloseControlling {
    private let helperClient: PrivilegedHelperClientProtocol

    public init(helperClient: PrivilegedHelperClientProtocol = PrivilegedHelperClient()) {
        self.helperClient = helperClient
    }

    public func enable() async throws {
        try await helperClient.installOrUpdateHelperIfNeeded()
        try await helperClient.enableLidClosePrevention()
    }

    public func disable() async throws {
        try await helperClient.disableLidClosePrevention()
    }

    public func status() async throws -> Bool {
        try await helperClient.readLidClosePreventionStatus()
    }
}
```

Create `Sources/InsomniaCore/PrivilegedHelperClient.swift`:

```swift
import Foundation

public enum PrivilegedHelperClientError: Error, LocalizedError, Equatable {
    case notImplemented
    case helperReturnedError(String)
    case invalidReply
    case authorizationFailed(OSStatus)
    case blessFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Privileged helper client is not implemented"
        case let .helperReturnedError(message):
            return message
        case .invalidReply:
            return "Privileged helper returned an invalid reply"
        case let .authorizationFailed(status):
            return "Authorization failed with status \(status)"
        case let .blessFailed(message):
            return "Helper installation failed: \(message)"
        }
    }
}

public final class PrivilegedHelperClient: PrivilegedHelperClientProtocol {
    public init() {}

    public func installOrUpdateHelperIfNeeded() async throws {
        throw PrivilegedHelperClientError.notImplemented
    }

    public func enableLidClosePrevention() async throws {
        throw PrivilegedHelperClientError.notImplemented
    }

    public func disableLidClosePrevention() async throws {
        throw PrivilegedHelperClientError.notImplemented
    }

    public func readLidClosePreventionStatus() async throws -> Bool {
        throw PrivilegedHelperClientError.notImplemented
    }
}
```

- [x] **Step 3: Run tests and commit**

Run:

```bash
cd /Users/tr0n/Code/insomnia && swift test --filter LidCloseControllerTests && make test
```

Expected: PASS.

Commit:

```bash
cd /Users/tr0n/Code/insomnia && git add Sources/InsomniaCore/InsomniaHelperProtocol.swift Sources/InsomniaCore/LidCloseController.swift Sources/InsomniaCore/PrivilegedHelperClient.swift Tests/InsomniaCoreTests/LidCloseControllerTests.swift && git commit -m "feat: add lid-close controller contract"
```

---

### Task 5: Privileged Helper Implementation

**Files:**
- Modify: `Sources/InsomniaCore/PrivilegedHelperClient.swift`
- Create: `Sources/InsomniaHelper/ApplePowerSettings.swift`
- Create: `Sources/InsomniaHelper/main.swift`
- Create: `Resources/InsomniaHelper/Info.plist`
- Create: `Resources/InsomniaHelper/launchd.plist`

- [x] **Step 1: Replace helper client stub with SMJobBless/XPC implementation**

Replace `Sources/InsomniaCore/PrivilegedHelperClient.swift` with:

```swift
import Foundation
import Security
import ServiceManagement

public enum PrivilegedHelperClientError: Error, LocalizedError, Equatable {
    case helperReturnedError(String)
    case invalidReply
    case authorizationFailed(OSStatus)
    case blessFailed(String)
    case xpcConnectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .helperReturnedError(message):
            return message
        case .invalidReply:
            return "Privileged helper returned an invalid reply"
        case let .authorizationFailed(status):
            return "Authorization failed with status \(status)"
        case let .blessFailed(message):
            return "Helper installation failed: \(message)"
        case let .xpcConnectionFailed(message):
            return "Helper connection failed: \(message)"
        }
    }
}

public final class PrivilegedHelperClient: PrivilegedHelperClientProtocol {
    private let helperIdentifier: String

    public init(helperIdentifier: String = InsomniaHelperConstants.helperBundleIdentifier) {
        self.helperIdentifier = helperIdentifier
    }

    public func installOrUpdateHelperIfNeeded() async throws {
        if let version = try? await helperVersion(), version == InsomniaHelperConstants.helperVersion {
            return
        }
        try blessHelper()
    }

    public func enableLidClosePrevention() async throws {
        try await callBooleanCommand { helper, reply in
            helper.enableLidClosePrevention(reply: reply)
        }
    }

    public func disableLidClosePrevention() async throws {
        try await callBooleanCommand { helper, reply in
            helper.disableLidClosePrevention(reply: reply)
        }
    }

    public func readLidClosePreventionStatus() async throws -> Bool {
        try await callBooleanCommand { helper, reply in
            helper.readLidClosePreventionStatus(reply: reply)
        }
    }

    private func helperVersion() async throws -> Int {
        let helper = try makeRemoteHelperProxy()
        return try await withCheckedThrowingContinuation { continuation in
            helper.helperVersion { version in
                continuation.resume(returning: version.intValue)
            }
        }
    }

    private func callBooleanCommand(
        _ command: @escaping (InsomniaHelperProtocol, @escaping (NSNumber, NSString?) -> Void) -> Void
    ) async throws -> Bool {
        let helper = try makeRemoteHelperProxy()
        return try await withCheckedThrowingContinuation { continuation in
            command(helper) { value, errorMessage in
                if let errorMessage {
                    continuation.resume(throwing: PrivilegedHelperClientError.helperReturnedError(errorMessage as String))
                } else {
                    continuation.resume(returning: value.boolValue)
                }
            }
        }
    }

    private func makeRemoteHelperProxy() throws -> InsomniaHelperProtocol {
        let connection = NSXPCConnection(machServiceName: helperIdentifier, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: InsomniaHelperProtocol.self)
        connection.resume()

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            NSLog("Insomnia helper XPC error: \(error.localizedDescription)")
        }) as? InsomniaHelperProtocol else {
            connection.invalidate()
            throw PrivilegedHelperClientError.xpcConnectionFailed("Could not create remote proxy")
        }

        return proxy
    }

    private func blessHelper() throws {
        var authRef: AuthorizationRef?
        var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value: nil, flags: 0)
        var authRights = AuthorizationRights(count: 1, items: &authItem)
        let flags: AuthorizationFlags = [.interactionAllowed, .preAuthorize, .extendRights]

        let authStatus = AuthorizationCreate(&authRights, nil, flags, &authRef)
        guard authStatus == errAuthorizationSuccess, let authRef else {
            throw PrivilegedHelperClientError.authorizationFailed(authStatus)
        }

        var unmanagedError: Unmanaged<CFError>?
        let blessed = SMJobBless(kSMDomainSystemLaunchd, helperIdentifier as CFString, authRef, &unmanagedError)
        guard blessed else {
            let message = unmanagedError?.takeRetainedValue().localizedDescription ?? "SMJobBless returned false"
            throw PrivilegedHelperClientError.blessFailed(message)
        }
    }
}
```

- [x] **Step 2: Implement helper power setting bridge**

Create `Sources/InsomniaHelper/ApplePowerSettings.swift`:

```swift
import CoreFoundation
import Foundation
import IOKit

private let sleepDisabledKey = "SleepDisabled" as CFString

@_silgen_name("IOPMSetSystemPowerSetting")
private func IOPMSetSystemPowerSetting(_ key: CFString, _ value: CFTypeRef) -> IOReturn

@_silgen_name("IOPMCopySystemPowerSettings")
private func IOPMCopySystemPowerSettings() -> Unmanaged<CFDictionary>?

enum ApplePowerSettingsError: Error, LocalizedError {
    case setFailed(IOReturn)
    case readFailed

    var errorDescription: String? {
        switch self {
        case let .setFailed(code):
            return "Failed to update SleepDisabled: IOReturn \(code)"
        case .readFailed:
            return "Failed to read SleepDisabled"
        }
    }
}

final class ApplePowerSettings {
    func setLidClosePreventionEnabled(_ enabled: Bool) throws {
        let value: CFBoolean = enabled ? kCFBooleanTrue : kCFBooleanFalse
        let result = IOPMSetSystemPowerSetting(sleepDisabledKey, value)
        guard result == kIOReturnSuccess else {
            throw ApplePowerSettingsError.setFailed(result)
        }
    }

    func isLidClosePreventionEnabled() throws -> Bool {
        guard let unmanaged = IOPMCopySystemPowerSettings() else {
            throw ApplePowerSettingsError.readFailed
        }

        let dictionary = unmanaged.takeRetainedValue() as NSDictionary
        return (dictionary[sleepDisabledKey as String] as? Bool) ?? false
    }
}
```

- [x] **Step 3: Implement helper XPC listener**

Create `Sources/InsomniaHelper/main.swift`:

```swift
import Foundation
import InsomniaCore

final class HelperDelegate: NSObject, NSXPCListenerDelegate, InsomniaHelperProtocol {
    private let powerSettings = ApplePowerSettings()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: InsomniaHelperProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func enableLidClosePrevention(reply: @escaping (NSNumber, NSString?) -> Void) {
        setLidClosePrevention(true, reply: reply)
    }

    func disableLidClosePrevention(reply: @escaping (NSNumber, NSString?) -> Void) {
        setLidClosePrevention(false, reply: reply)
    }

    func readLidClosePreventionStatus(reply: @escaping (NSNumber, NSString?) -> Void) {
        do {
            let enabled = try powerSettings.isLidClosePreventionEnabled()
            reply(NSNumber(value: enabled), nil)
        } catch {
            reply(false, error.localizedDescription as NSString)
        }
    }

    func helperVersion(reply: @escaping (NSNumber) -> Void) {
        reply(NSNumber(value: InsomniaHelperConstants.helperVersion))
    }

    private func setLidClosePrevention(_ enabled: Bool, reply: @escaping (NSNumber, NSString?) -> Void) {
        do {
            try powerSettings.setLidClosePreventionEnabled(enabled)
            let actual = try powerSettings.isLidClosePreventionEnabled()
            reply(NSNumber(value: actual == enabled), nil)
        } catch {
            reply(false, error.localizedDescription as NSString)
        }
    }
}

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: InsomniaHelperConstants.helperBundleIdentifier)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
```

- [x] **Step 4: Add helper embedded metadata**

Create `Resources/InsomniaHelper/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.tonioriol.insomnia.helper</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>InsomniaHelper</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>SMAuthorizedClients</key>
  <array>
    <string>identifier com.tonioriol.insomnia</string>
  </array>
</dict>
</plist>
```

Create `Resources/InsomniaHelper/launchd.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.tonioriol.insomnia.helper</string>
  <key>MachServices</key>
  <dict>
    <key>com.tonioriol.insomnia.helper</key>
    <true/>
  </dict>
</dict>
</plist>
```

- [x] **Step 5: Build and commit helper implementation**

Run:

```bash
cd /Users/tr0n/Code/insomnia && swift build
```

Expected: PASS and both app/helper executables compile.

Commit:

```bash
cd /Users/tr0n/Code/insomnia && git add Sources/InsomniaCore/PrivilegedHelperClient.swift Sources/InsomniaHelper Resources/InsomniaHelper Package.swift && git commit -m "feat: add privileged helper implementation"
```

---

### Task 6: App Bundle Packaging and Signing

**Files:**
- Modify: `Makefile`
- Create: `Resources/Insomnia/Info.plist`

- [x] **Step 1: Add app bundle metadata**

Create `Resources/Insomnia/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Insomnia</string>
  <key>CFBundleIdentifier</key>
  <string>com.tonioriol.insomnia</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Insomnia</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>SMPrivilegedExecutables</key>
  <dict>
    <key>com.tonioriol.insomnia.helper</key>
    <string>identifier com.tonioriol.insomnia.helper</string>
  </dict>
</dict>
</plist>
```

- [x] **Step 2: Replace Makefile with bundling commands**

Replace `Makefile` with:

```makefile
SHELL := /bin/zsh
CONFIGURATION ?= debug
SWIFT_BUILD_FLAGS := -c $(CONFIGURATION)
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/Insomnia.app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
LAUNCH_SERVICES_DIR := $(CONTENTS_DIR)/Library/LaunchServices
SWIFT_BIN_DIR := .build/$(CONFIGURATION)
CODE_SIGN_IDENTITY ?= -

.PHONY: test build app sign run clean verify-helper-sections

test:
	swift test

build:
	swift build $(SWIFT_BUILD_FLAGS)

app: build
	rm -rf $(APP_DIR)
	mkdir -p $(MACOS_DIR) $(LAUNCH_SERVICES_DIR)
	cp Resources/Insomnia/Info.plist $(CONTENTS_DIR)/Info.plist
	cp $(SWIFT_BIN_DIR)/Insomnia $(MACOS_DIR)/Insomnia
	cp $(SWIFT_BIN_DIR)/InsomniaHelper $(LAUNCH_SERVICES_DIR)/com.tonioriol.insomnia.helper
	$(MAKE) sign

sign:
	codesign --force --sign "$(CODE_SIGN_IDENTITY)" $(LAUNCH_SERVICES_DIR)/com.tonioriol.insomnia.helper
	codesign --force --sign "$(CODE_SIGN_IDENTITY)" --deep $(APP_DIR)

verify-helper-sections:
	otool -s __TEXT __info_plist $(SWIFT_BIN_DIR)/InsomniaHelper >/dev/null
	otool -s __TEXT __launchd_plist $(SWIFT_BIN_DIR)/InsomniaHelper >/dev/null

run: app
	open $(APP_DIR)

clean:
	rm -rf .build build
```

- [x] **Step 3: Build package and verify helper sections**

Run:

```bash
cd /Users/tr0n/Code/insomnia && make build && make verify-helper-sections
```

Expected: PASS. `otool` exits 0 for both embedded helper plist sections.

- [x] **Step 4: Build the app bundle**

Run:

```bash
cd /Users/tr0n/Code/insomnia && make app
```

Expected: PASS and `build/Insomnia.app/Contents/MacOS/Insomnia` plus `build/Insomnia.app/Contents/Library/LaunchServices/com.tonioriol.insomnia.helper` exist.

- [x] **Step 5: Commit bundling work**

Commit:

```bash
cd /Users/tr0n/Code/insomnia && git add Makefile Resources/Insomnia/Info.plist && git commit -m "build: package app bundle with helper"
```

---

### Task 7: Menu Bar App UI

**Files:**
- Create: `Sources/Insomnia/main.swift`
- Create: `Sources/Insomnia/AppDelegate.swift`
- Create: `Sources/Insomnia/MenuBarController.swift`

- [x] **Step 1: Implement app entry point**

Create `Sources/Insomnia/main.swift`:

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [x] **Step 2: Implement app delegate**

Create `Sources/Insomnia/AppDelegate.swift`:

```swift
import AppKit
import InsomniaCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        let awake = AwakeController()
        let lidClose = LidCloseController()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lidClose)

        self.coordinator = coordinator
        self.menuBarController = MenuBarController(state: state, coordinator: coordinator)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let coordinator else { return .terminateNow }
        Task { @MainActor in
            await coordinator.turnOff()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
```

- [x] **Step 3: Implement status item controller**

Create `Sources/Insomnia/MenuBarController.swift`:

```swift
import AppKit
import Combine
import InsomniaCore

@MainActor
final class MenuBarController: NSObject {
    private let state: AppState
    private let coordinator: AppCoordinator
    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []

    init(state: AppState, coordinator: AppCoordinator) {
        self.state = state
        self.coordinator = coordinator
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
        let symbolName: String
        if state.isBusy {
            symbolName = "hourglass"
        } else if state.isActive {
            symbolName = "cup.and.saucer.fill"
        } else if state.lastErrorMessage != nil {
            symbolName = "exclamationmark.triangle"
        } else {
            symbolName = "cup.and.saucer"
        }

        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Insomnia")
        image?.isTemplate = true
        button.image = image
        button.toolTip = tooltipText
    }

    private var tooltipText: String {
        if state.isBusy { return "Insomnia is changing sleep prevention state" }
        if state.isActive { return "Insomnia is preventing sleep, including lid-close sleep" }
        if let error = state.lastErrorMessage { return "Insomnia is off: \(error)" }
        return "Insomnia is off"
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

        let aboutItem = NSMenuItem(title: "About Insomnia", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let repairItem = NSMenuItem(title: "Repair/Install Helper", action: #selector(repairHelper), keyEquivalent: "")
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

    @objc
    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: "Keep-awake utility inspired by Caffeine and Fermata."),
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

- [x] **Step 4: Build app bundle and commit UI**

Run:

```bash
cd /Users/tr0n/Code/insomnia && make app
```

Expected: PASS.

Commit:

```bash
cd /Users/tr0n/Code/insomnia && git add Sources/Insomnia && git commit -m "feat: add one-click menu bar UI"
```

---

### Task 8: Documentation, Attribution, and Manual Verification

**Files:**
- Create: `README.md`
- Create: `NOTICE.md`
- Modify: `docs/feat/20260424192541-merge-fermatta-caffeine/context.md`

- [x] **Step 1: Add README**

Create `README.md`:

```markdown
# Insomnia

macOS menu bar app with one on/off icon. When on, it prevents ordinary sleep and lid-close sleep. When off, it restores normal sleep behavior.

## Safety

Do not put a closed MacBook into a bag while Insomnia is on. Lid-close sleep prevention can leave the machine running and may cause overheating.

## Build

```bash
make test
make app
```

The app bundle is created at `build/Insomnia.app`.

## Run

```bash
make run
```

The first activation may request admin authorization to install the privileged helper.

## Behavior

- Left-click menu bar icon: toggle off/on.
- Off: normal sleep behavior.
- On: ordinary sleep and lid-close sleep are prevented.
- Right-click menu: About, helper repair when needed, Quit.
```

- [x] **Step 2: Add upstream attribution**

Create `NOTICE.md`:

```markdown
# Notices

Insomnia is a clean reimplementation informed by these open-source macOS utilities:

- Caffeine: https://github.com/domzilla/Caffeine — MIT License. Used as a behavioral reference for simple menu bar keep-awake UX and ordinary IOKit sleep assertions.
- Fermata: https://github.com/iccir/Fermata — MIT License or BSD-1-Clause. Used as a behavioral/platform reference for privileged lid-close sleep prevention.

If code is copied directly from either project in future changes, preserve the upstream copyright notice beside the copied code and update this file.
```

- [x] **Step 3: Run automated verification**

Run:

```bash
cd /Users/tr0n/Code/insomnia && make clean && make test && make app
```

Expected: PASS.

- [x] **Step 4: Run manual verification**

Run:

```bash
cd /Users/tr0n/Code/insomnia && make run
```

Expected:

- No Dock icon appears.
- A menu bar icon appears.
- Left-click prompts for admin authorization on first activation if helper is not installed.
- If authorization is cancelled, icon remains off.
- If activation succeeds, icon changes to active.
- Left-click again turns off and restores normal sleep settings.
- Quit while active restores normal sleep settings before exit.

- [x] **Step 5: Update task ledger and commit docs**

Append this entry to `docs/feat/20260424192541-merge-fermatta-caffeine/context.md` after implementation evidence exists:

```markdown
### 2026-04-25 HH:MM — Implementation verified

- Why: The app now implements the approved one-toggle keep-awake behavior.
- How: `make clean && make test && make app` passed; manual menu bar activation/deactivation restored normal sleep behavior on quit.
- Decision: The initial version excludes durations, app rules, and advanced controls as intended.
```

Commit:

```bash
cd /Users/tr0n/Code/insomnia && git add README.md NOTICE.md docs/feat/20260424192541-merge-fermatta-caffeine/context.md && git commit -m "docs: add build and verification notes"
```

---

## Self-Review

Spec coverage:

- One-click menu bar icon: Task 7.
- Ordinary sleep prevention: Task 3.
- Lid-close sleep prevention through admin-authorized helper: Tasks 4, 5, and 6.
- Off-state cleanup and quit cleanup: Tasks 2 and 7.
- Clean Swift-compatible reimplementation: Tasks 1 through 7 use new Swift files and upstreams only as references.
- Attribution: Task 8.
- Tests and manual verification: Tasks 1 through 4 and Task 8.

Placeholder scan: no deferred implementation placeholders are intended; every task names exact files, commands, expected outcomes, and code content for new implementation files.

Type consistency: `AppCoordinator`, `AppState`, `AwakeController`, `LidCloseController`, `PrivilegedHelperClient`, and `InsomniaHelperProtocol` names/signatures are consistent across tasks.
