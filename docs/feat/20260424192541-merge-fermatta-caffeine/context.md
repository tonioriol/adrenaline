---
title: "Build Cocaine, a simple macOS keep-awake app"
status: active
tags: [macos]
created: 2026-04-24
---

# Build Cocaine, a simple macOS keep-awake app

## TASK

**Goal:** Design and implement a personal macOS menu bar app named “Cocaine” with a Caffeine-like single clickable on/off icon where the on state prevents sleep even when the MacBook lid is closed.

The app should live at `/Users/tr0n/Code/cocaine`. It should be a clean Swift/SwiftUI reimplementation informed by Caffeine and Fermata, not a wholesale fork of either. Upstream references are cloned at `Dev/merge-fermatta-caffeine/upstreams/Caffeine` and `Dev/merge-fermatta-caffeine/upstreams/Fermata`. Full lid-close prevention requires a privileged helper/admin authorization path like Fermata; normal idle/display prevention can use regular IOKit assertions like Caffeine.

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
- `Resources/CocaineHelper/Info.plist` — helper metadata placeholder required by linker flags
- `Resources/CocaineHelper/launchd.plist` — helper launchd metadata placeholder required by linker flags
- `Sources/Cocaine/main.swift` — app executable placeholder
- `Sources/CocaineCore/AppCoordinator.swift` — one-toggle coordinator and controller protocols
- `Sources/CocaineCore/AppState.swift` — observable state model
- `Sources/CocaineHelper/main.swift` — helper executable placeholder
- `Tests/CocaineCoreTests/AppCoordinatorTests.swift` — coordinator unit tests
- `Tests/CocaineCoreTests/AppStateTests.swift` — AppState unit tests

## PLAN

**Plan:** [plan.md](./plan.md)

**Cursor:** Task 3 — Ordinary Sleep Prevention

**Status:** ready

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
- Decision: Initial design excludes durations, app rules, advanced lid-close automation, and separate feature toggles. The visible app name is “Cocaine” for personal use, and the target folder is `/Users/tr0n/Code/cocaine`.

### 2026-04-25 09:17 — Task docs moved under project folder

- Why: User wants task documentation to live under the `cocaine` project folder rather than the Desktop workspace root.
- How: Created `Code/cocaine/docs/feat/20260424192541-merge-fermatta-caffeine/` and moved the current task ledger/spec there.
- Decision: Treat `Code/cocaine` as the project root for docs and future implementation work.

### 2026-04-25 09:27 — Implementation plan generated

- Why: The simplified spec was approved and needs an executable plan before code changes.
- How: Wrote `docs/feat/20260424192541-merge-fermatta-caffeine/plan.md` with eight tasks covering project skeleton, state orchestration, ordinary assertions, helper protocol/client, privileged helper, app bundling, menu bar UI, and verification docs.
- Decision: Start implementation at Task 1 using the plan cursor above.

### 2026-04-25 09:30 — Task 1 project skeleton and state model

- Why: Establish the SwiftPM package foundation and a tested observable state model before adding coordinator, power assertion, helper, and UI behavior.
- How: Added `Package.swift`, `Makefile`, `Sources/CocaineCore/AppState.swift`, `Tests/CocaineCoreTests/AppStateTests.swift`, minimal executable target entry points, and helper plist resources required by the manifest linker flags. TDD evidence: `swift test` first failed with missing `Package.swift`, then `make test` passed with 3 AppState tests after implementation. Commit: `db1f77a`.

### 2026-04-25 09:39 — Task 1 quality fixes

- Why: Code quality review found AppState could represent inconsistent error/helper state and generated build outputs were unignored.
- How: Tightened AppState transition invariants, expanded AppState tests, added .gitignore, verified with `swift test --filter AppStateTests`, `make test`, and `git status --short`, commit `6705ae8`.

### 2026-04-25 09:47 — Task 2 one-toggle coordinator

- Why: Add the central orchestration point for the app’s single on/off action so ordinary awake prevention and lid-close prevention are enabled and disabled together.
- How: Added `Sources/CocaineCore/AppCoordinator.swift` with controller protocols, status validation, rollback, and AppState error recording; added `Tests/CocaineCoreTests/AppCoordinatorTests.swift` covering on, off, enable failure rollback, and false status rollback. TDD evidence: `swift test --filter AppCoordinatorTests` failed before implementation because coordinator/protocol symbols were missing, then `swift test --filter AppCoordinatorTests && make test` passed with 11 total XCTest tests. Commit: `517addd`.
- Decision: Let `AppState.recordError(_:)` own failure-state normalization so coordinator rollback records only the user-visible localized error after disabling any partially enabled controllers.

### 2026-04-25 09:55 — Task 2 quality fixes

- Why: Code quality review found missing busy-guard coverage and ambiguous post-disable status handling.
- How: Added busy-guard/error-state tests, treated active status after disable as a coordinator error, verified with `swift test --filter AppCoordinatorTests` and `make test`, commit `313ed13`.

### 2026-04-25 10:01 — Task 3 ordinary sleep prevention

- Why: Add concrete ordinary idle/display sleep prevention behind the coordinator’s awake controller contract.
- How: Added `Sources/CocaineCore/PowerAssertionClient.swift` with fakeable IOKit assertion creation/release, `Sources/CocaineCore/AwakeController.swift` with idempotent enable and release-on-disable behavior, and `Tests/CocaineCoreTests/AwakeControllerTests.swift` covering assertion creation, release, and idempotence. TDD evidence: `swift test --filter AwakeControllerTests` first failed because `PowerAssertionClient` and `AwakeController` were missing, then `swift test --filter AwakeControllerTests && make test` passed with 16 total XCTest tests. Commit: `ba1e5ab`.
- Decision: Keep Task 3 limited to ordinary no-idle/display assertions via public IOKit APIs; lid-close/helper behavior remains deferred to the next task.

### 2026-04-25 10:07 — Task 3 quality fixes

- Why: Code quality review found `AwakeController.enable()` leaked a no-idle assertion if display assertion creation failed.
- How: Released locally tracked partial assertion IDs on enable failure, added regression coverage, verified with `swift test --filter AwakeControllerTests` and `make test`, commit `f285edc`.
