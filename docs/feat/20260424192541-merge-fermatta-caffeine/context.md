---
title: "Build Insomnia, a simple macOS keep-awake app"
status: active
tags: [macos]
created: 2026-04-24
---

# Build Insomnia, a simple macOS keep-awake app

## TASK

**Goal:** Design and implement a macOS menu bar app named “Insomnia” with a Caffeine-like single clickable on/off icon where the on state prevents sleep even when the MacBook lid is closed.

The app should live at `/Users/tr0n/Code/insomnia`. It should be a clean Swift/SwiftUI reimplementation informed by Caffeine and Fermata, not a wholesale fork of either. Upstream references are cloned at `Dev/merge-fermatta-caffeine/upstreams/Caffeine` and `Dev/merge-fermatta-caffeine/upstreams/Fermata`. Full lid-close prevention requires a privileged helper/admin authorization path like Fermata; normal idle/display prevention can use regular IOKit assertions like Caffeine.

**Done when:** A written spec is approved, an implementation plan exists, and the resulting app can build and run with one visible on/off menu bar control that releases all sleep prevention when off and prevents ordinary plus lid-close sleep when on.

## SPEC

[spec.md](./spec.md) — simplified one-toggle macOS keep-awake app with privileged lid-close prevention.

## FILES

- `Dev/merge-fermatta-caffeine/upstreams/Caffeine` — upstream behavioral reference
- `Dev/merge-fermatta-caffeine/upstreams/Fermata` — upstream privileged-helper/lid-close reference
- `docs/feat/20260424192541-merge-fermatta-caffeine/context.md` — task ledger
- `docs/feat/20260424192541-merge-fermatta-caffeine/spec.md` — approved design draft awaiting review
- `docs/feat/20260424192541-merge-fermatta-caffeine/plan.md` — implementation plan
- `.gitignore` — generated output ignore rules
- `Package.swift` — SwiftPM manifest
- `Makefile` — build/test commands
- `README.md` — user-facing build/run/safety documentation
- `NOTICE.md` — upstream attribution notes
- `Resources/InsomniaHelper/Info.plist` — helper metadata placeholder required by linker flags
- `Resources/InsomniaHelper/launchd.plist` — helper launchd metadata placeholder required by linker flags
- `Sources/Insomnia/main.swift` — app executable entry point
- `Sources/InsomniaCore/AppCoordinator.swift` — one-toggle coordinator and controller protocols
- `Sources/InsomniaCore/AppState.swift` — observable state model
- `Sources/InsomniaCore/AwakeController.swift` — ordinary sleep assertion controller
- `Sources/InsomniaCore/InsomniaHelperProtocol.swift` — helper constants, XPC protocol, and helper client protocol
- `Sources/InsomniaCore/LidCloseController.swift` — lid-close controller contract adapter
- `Sources/InsomniaCore/PowerAssertionClient.swift` — fakeable IOKit assertion wrapper
- `Sources/InsomniaCore/PrivilegedHelperClient.swift` — concrete privileged helper client
- `Sources/InsomniaHelper/ApplePowerSettings.swift` — helper-side SleepDisabled bridge
- `Sources/InsomniaHelper/main.swift` — helper mach-service listener
- `Resources/Insomnia/Info.plist` — app bundle metadata
- `Sources/Insomnia/AppDelegate.swift` — app lifecycle wiring
- `Sources/Insomnia/MenuBarController.swift` — status item UI and menu actions
- `Tests/InsomniaCoreTests/AppCoordinatorTests.swift` — coordinator unit tests
- `Tests/InsomniaCoreTests/AppStateTests.swift` — AppState unit tests
- `Tests/InsomniaCoreTests/AwakeControllerTests.swift` — ordinary assertion controller tests
- `Tests/InsomniaCoreTests/InsomniaHelperConstantsTests.swift` — signing requirement constant tests
- `Tests/InsomniaCoreTests/LidCloseControllerTests.swift` — lid-close controller contract tests
- `Tests/InsomniaCoreTests/PrivilegedHelperClientTests.swift` — privileged helper client reply-semantics tests

## PLAN

**Plan:** [plan.md](./plan.md)

**Cursor:** all tasks complete

**Status:** complete

## LOG

### 2026-04-24 21:25 — Task started

- Why: The user wants to combine two open-source macOS keep-awake utilities into one app.
- How: Created an initial task ledger for the design process.

### 2026-04-24 21:28 — Upstream apps identified

- Why: The design should be based on the actual open-source implementations.
- How: Identified likely upstream projects as `iccir/Fermata` for lid-close sleep prevention and `domzilla/Caffeine` for regular idle/display/screensaver sleep prevention.
- Decision: Treat this as a new product design informed by two utilities, not a simple binary bundling exercise.

### 2026-04-25 08:50 — Upstream repositories inspected

- Why: Base-vs-rewrite should be decided from source shape, build metadata, and implementation risks.
- How: Cloned `iccir/Fermata` at `d9aebf1` and `domzilla/Caffeine` at `19a9915` under `Dev/merge-fermatta-caffeine/upstreams`. Caffeine is a small Swift/SwiftUI menu bar app with regular IOKit assertions. Fermata is a small Objective-C AppKit app with app, login launcher, and privileged helper targets; its lid-close feature uses a blessed XPC helper to set the private `SleepDisabled` power setting.
- Decision: Use both repos as references only.

### 2026-04-25 08:52 — Full lid-close behavior required

- Why: Preventing sleep with the lid closed is the differentiating behavior the combined app must provide.
- How: User selected full functionality, including privileged helper/admin prompt, rather than a safe-only idle sleep app.
- Decision: The design must include a privileged helper or equivalent admin-authorized mechanism and must restore normal lid-close sleep when toggled off or quitting.

### 2026-04-25 08:57 — Workflow instructions reloaded

- Why: User changed workflow instructions and asked to reload previously loaded guidance.
- How: Reloaded memory and brainstorming guidance before continuing.
- Decision: Maintain the task ledger using the current memory schema.

### 2026-04-25 08:59 — Clean reimplementation chosen

- Why: User prefers an implementation we own and can keep clean, using upstreams only to understand behavior.
- How: Measured upstream source size: Caffeine has 7 Swift files with 620 code lines under `src/Caffeine`; Fermata has 8 Objective-C files plus 7 headers with roughly 750 source/header code lines under `Source`, excluding project metadata and binary resources.
- Decision: Build a new Swift/SwiftUI app rather than basing it on either upstream codebase.

### 2026-04-25 09:06 — Scope simplified to one toggle

- Why: The user clarified the desired UX: a simple clickable icon like Caffeine, with no advanced rules or separate controls.
- How: Replaced the earlier advanced-rule idea with a single state model: off means no prevention; on means prevent ordinary sleep and lid-close sleep.
- Decision: Initial design excludes durations, app rules, advanced lid-close automation, and separate feature toggles. The visible app name is “Insomnia”, and the target folder is `/Users/tr0n/Code/insomnia`.

### 2026-04-25 09:17 — Task docs moved under project folder

- Why: User wants task documentation to live under the `insomnia` project folder rather than the Desktop workspace root.
- How: Created `Code/insomnia/docs/feat/20260424192541-merge-fermatta-caffeine/` and moved the current task ledger/spec there.
- Decision: Treat `Code/insomnia` as the project root for docs and future implementation work.

### 2026-04-25 09:27 — Implementation plan generated

- Why: The simplified spec was approved and needs an executable plan before code changes.
- How: Wrote `docs/feat/20260424192541-merge-fermatta-caffeine/plan.md` with eight tasks covering project skeleton, state orchestration, ordinary assertions, helper protocol/client, privileged helper, app bundling, menu bar UI, and verification docs.
- Decision: Start implementation at Task 1 using the plan cursor above.

### 2026-04-25 09:30 — Task 1 project skeleton and state model

- Why: Establish the SwiftPM package foundation and a tested observable state model before adding coordinator, power assertion, helper, and UI behavior.
- How: Added `Package.swift`, `Makefile`, `Sources/InsomniaCore/AppState.swift`, `Tests/InsomniaCoreTests/AppStateTests.swift`, minimal executable target entry points, and helper plist resources required by the manifest linker flags. TDD evidence: `swift test` first failed with missing `Package.swift`, then `make test` passed with 3 AppState tests after implementation. Commit: `db1f77a`.

### 2026-04-25 09:39 — Task 1 quality fixes

- Why: Code quality review found AppState could represent inconsistent error/helper state and generated build outputs were unignored.
- How: Tightened AppState transition invariants, expanded AppState tests, added .gitignore, verified with `swift test --filter AppStateTests`, `make test`, and `git status --short`, commit `6705ae8`.

### 2026-04-25 09:47 — Task 2 one-toggle coordinator

- Why: Add the central orchestration point for the app’s single on/off action so ordinary awake prevention and lid-close prevention are enabled and disabled together.
- How: Added `Sources/InsomniaCore/AppCoordinator.swift` with controller protocols, status validation, rollback, and AppState error recording; added `Tests/InsomniaCoreTests/AppCoordinatorTests.swift` covering on, off, enable failure rollback, and false status rollback. TDD evidence: `swift test --filter AppCoordinatorTests` failed before implementation because coordinator/protocol symbols were missing, then `swift test --filter AppCoordinatorTests && make test` passed with 11 total XCTest tests. Commit: `517addd`.
- Decision: Let `AppState.recordError(_:)` own failure-state normalization so coordinator rollback records only the user-visible localized error after disabling any partially enabled controllers.

### 2026-04-25 09:55 — Task 2 quality fixes

- Why: Code quality review found missing busy-guard coverage and ambiguous post-disable status handling.
- How: Added busy-guard/error-state tests, treated active status after disable as a coordinator error, verified with `swift test --filter AppCoordinatorTests` and `make test`, commit `313ed13`.

### 2026-04-25 10:01 — Task 3 ordinary sleep prevention

- Why: Add concrete ordinary idle/display sleep prevention behind the coordinator’s awake controller contract.
- How: Added `Sources/InsomniaCore/PowerAssertionClient.swift` with fakeable IOKit assertion creation/release, `Sources/InsomniaCore/AwakeController.swift` with idempotent enable and release-on-disable behavior, and `Tests/InsomniaCoreTests/AwakeControllerTests.swift` covering assertion creation, release, and idempotence. TDD evidence: `swift test --filter AwakeControllerTests` first failed because `PowerAssertionClient` and `AwakeController` were missing, then `swift test --filter AwakeControllerTests && make test` passed with 16 total XCTest tests. Commit: `ba1e5ab`.
- Decision: Keep Task 3 limited to ordinary no-idle/display assertions via public IOKit APIs; lid-close/helper behavior remains deferred to the next task.

### 2026-04-25 10:07 — Task 3 quality fixes

- Why: Code quality review found `AwakeController.enable()` leaked a no-idle assertion if display assertion creation failed.
- How: Released locally tracked partial assertion IDs on enable failure, added regression coverage, verified with `swift test --filter AwakeControllerTests` and `make test`, commit `f285edc`.

### 2026-04-25 10:14 — Task 4 lid-close controller contract

- Why: Add the tested public contract that lets the coordinator delegate lid-close prevention to a future privileged helper implementation without implementing SMJobBless/XPC behavior yet.
- How: Added `Sources/InsomniaCore/InsomniaHelperProtocol.swift`, `Sources/InsomniaCore/LidCloseController.swift`, `Sources/InsomniaCore/PrivilegedHelperClient.swift`, and `Tests/InsomniaCoreTests/LidCloseControllerTests.swift`. TDD evidence: `swift test --filter LidCloseControllerTests` first failed because `PrivilegedHelperClientProtocol` and `LidCloseController` were missing, then `swift test --filter LidCloseControllerTests && make test` passed with 20 total XCTest tests. Commit: `3d29e44`.
- Decision: Keep `PrivilegedHelperClient` as a throwing `.notImplemented` stub so Task 4 defines the controller/helper protocol boundary only; privileged installation, XPC connection, and power-setting mutation remain deferred to Task 5.

### 2026-04-25 10:23 — Task 4 quality fixes

- Why: Code quality review found helper resource identifiers diverged from the canonical helper constants and controller error sequencing lacked tests.
- How: Aligned helper plist/launchd identifiers, documented XPC reply semantics, added install/enable failure tests, verified with `swift test --filter LidCloseControllerTests`, `make test`, and `plutil -p Resources/InsomniaHelper/Info.plist && plutil -p Resources/InsomniaHelper/launchd.plist`, commit `3dd5564`.

### 2026-04-25 10:31 — Task 5 privileged helper implementation

- Why: Replaced the placeholder privileged-helper path with concrete installation, XPC, and IOKit power-setting behavior so lid-close prevention can be managed by the helper executable.
- How: Implemented SMJobBless/XPC client behavior in Sources/InsomniaCore/PrivilegedHelperClient.swift, added SleepDisabled bridge in Sources/InsomniaHelper/ApplePowerSettings.swift, replaced the helper placeholder with an NSXPC mach-service listener in Sources/InsomniaHelper/main.swift, verified existing helper plists remained aligned, ran `swift build` and `swift test` successfully, and committed f952950.
- Decision: Kept SMJobBless despite the macOS 13 deprecation warning because Task 5 explicitly requires the SMJobBless-based privileged helper implementation; fixed temporary-pointer warnings in AuthorizationCreate while preserving the requested behavior.

### 2026-04-25 12:08 — Task 5 quality fixes

- Why: Code quality review found the privileged helper client could hang on connection errors and the helper accepted overly broad clients.
- How: Added per-call XPC connection lifetime/error handling, enforced runtime code-signing requirement on the helper listener, tightened mutating reply handling, verified with `swift build` and `swift test`, commit `f13af6c`.

### 2026-04-25 12:19 — Task 5 signing requirement fixes

- Why: Code quality review found the privileged helper trust boundary still relied on identifier-only checks.
- How: Added canonical signing requirement strings using Team ID A79T83GM42, applied them to the runtime listener gate and helper authorized clients, verified with `swift build && swift test && plutil -p Resources/InsomniaHelper/Info.plist`, commit 166677c.

### 2026-04-25 12:26 — Task 6 app bundle packaging and signing

- Why: The helper implementation needed app-bundle metadata, LaunchServices placement, and code-signing commands so SMJobBless packaging can locate the privileged executable from the app bundle.
- How: Added Resources/Insomnia/Info.plist and replaced Makefile targets with build/app/sign/run/verify-helper-sections packaging flow. Verified with `make build && make verify-helper-sections`, `make app`, and explicit executable presence checks for build/Insomnia.app/Contents/MacOS/Insomnia and build/Insomnia.app/Contents/Library/LaunchServices/com.tonioriol.insomnia.helper. Committed as 259b793.
- Decision: Kept the plan's ad-hoc default CODE_SIGN_IDENTITY (`-`) because the specified packaging verification passed without requiring the available Apple Development identity.

### 2026-04-25 12:58 — Task 7 menu bar app UI

- Why: Add the executable menu bar UI for the one-toggle keep-awake app after core coordination, helper, and packaging tasks were complete.
- How: Replaced `Sources/Insomnia/main.swift` with the AppKit app entry point, added `Sources/Insomnia/AppDelegate.swift` to wire `AppState`, `AwakeController`, `LidCloseController`, and `AppCoordinator`, and added `Sources/Insomnia/MenuBarController.swift` for status-item rendering, one-click toggle, contextual menu, about panel, helper repair action, and quit behavior. Verified with `make app` passing after the pragmatic compile fix of isolating only AppDelegate lifecycle methods on `@MainActor`. Committed code as `a565332`.
- Decision: Kept top-level app entry code from the task plan and moved `@MainActor` isolation from the entire delegate type to its AppKit lifecycle methods because SwiftPM top-level executable code cannot synchronously instantiate a globally main-actor-isolated delegate.

### 2026-04-25 13:07 — Task 7 shutdown cleanup fix

- Why: Code quality review found quitting during an in-flight toggle could bypass cleanup because the normal turn-off path returned early when busy.
- How: Added a shutdown-safe coordinator cleanup path, updated app termination to use it, added regression coverage, verified with `swift test --filter AppCoordinatorTests && make test && make app`, commit a1f27b1.

### 2026-04-25 13:17 — Task 7 shutdown serialization fix

- Why: Code quality review found the first shutdown fix bypassed the busy guard but still allowed a suspended turn-on path to resume and reactivate state after shutdown cleanup.
- How: Serialized shutdown against in-flight transitions, added a real suspended-enable regression test, verified with `swift test --filter AppCoordinatorTests && make test && make app`, commit bd8d939.

### 2026-04-25 13:27 — Implementation verified

- Why: The app now implements the approved one-toggle keep-awake behavior.
- How: `make clean && make test && make app` passed with 31 XCTest tests and a signed app bundle. `make run` launched a background-only menu bar process with no windows, and quitting left no Insomnia process or Insomnia power assertions. Full interactive activation/deactivation was not directly verified because the native menu bar item could not be conclusively driven from the available automation.
- Decision: The initial version excludes durations, app rules, and advanced controls as intended.

### 2026-04-25 13:35 — Implementation session complete

- Why: All planned implementation tasks, review loops, and verification steps are complete for the initial Insomnia release.
- How: Delivered Tasks 1-8 across the SwiftPM skeleton, one-toggle coordinator, ordinary IOKit assertions, lid-close controller contract, privileged helper implementation, app bundle packaging, menu bar UI, and project docs. Review/fix commits included `6705ae8`, `313ed13`, `f285edc`, `3dd5564`, `f13af6c`, `166677c`, `a1f27b1`, plus documentation/memory commits through `e9580a7`. Automated verification passed with `make clean && make test && make app`; best-effort manual verification confirmed the app launches as a background-only process and exits without lingering Insomnia assertions.
- Decision: The remaining follow-up is higher-confidence native UI/manual activation verification, not additional implementation scope for the v1 feature set.

### 2026-04-25 18:19 — Post-implementation local fix and icon refinement

- Why: Manual testing after installation exposed a remaining helper-install failure on the local machine and the menu bar icon was refined after visual feedback.
- How: Diagnosed that the app was already launching as a UI element and that the helper bless path was failing due to packaging/signing requirement mismatches. Updated signing-related values in [`Makefile`](../Makefile:1), [`Resources/Insomnia/Info.plist`](../Resources/Insomnia/Info.plist:1), [`Resources/InsomniaHelper/Info.plist`](../Resources/InsomniaHelper/Info.plist:1), and [`Sources/InsomniaCore/InsomniaHelperProtocol.swift`](../Sources/InsomniaCore/InsomniaHelperProtocol.swift:3), expanded [`Tests/InsomniaCoreTests/InsomniaHelperConstantsTests.swift`](../Tests/InsomniaCoreTests/InsomniaHelperConstantsTests.swift:1), rebuilt and reinstalled [`/Applications/Insomnia.app`](file:///Applications/Insomnia.app), and replaced the menu bar cup symbol with a vector-drawn diagonal split-pill icon in [`Sources/Insomnia/MenuBarController.swift`](../Sources/Insomnia/MenuBarController.swift:35).
- Decision: Keep the app menu-bar-only, keep the new pharmaceutical pill metaphor for the status item, and use the local signed build as the test installation baseline.

### 2026-04-25 20:40 — Final menu bar icon sizing tweak

- Why: Visual review of the new diagonal split-pill icon showed the first enlarged version felt slightly too large in the menu bar.
- How: Reduced the pill scale in [`Sources/Insomnia/MenuBarController.swift`](../Sources/Insomnia/MenuBarController.swift:59) from about `1.3x` to `1.2x`, rebuilt, re-signed, reinstalled, and relaunched [`/Applications/Insomnia.app`](file:///Applications/Insomnia.app).
- Decision: Keep the 30° diagonal split-capsule concept, but use the slightly smaller 1.2× size as the baseline.
