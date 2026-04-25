---
title: "Configurable lid-close behavior settings"
status: active
repos: [cocaine]
tags: [macos]
created: 2026-04-25
---

# Configurable lid-close behavior settings

## TASK

**Goal:** Design and add a small set of user-visible settings that control how Cocaine behaves when the lid closes while it is on, so the user can opt in or out of lid-close sleep prevention and choose the screen/lock side effects.

The user's musing in [`docs/scratch.md`](../../scratch.md:1) raises three related questions:

1. Whether lid-close sleep prevention should be a separate setting, distinct from the main on/off toggle (which today bundles ordinary sleep prevention and lid-close prevention together).
2. Whether the screen should stay on or be allowed to turn off when the lid is closed, and whether disk sleep is worth a setting at all (the user already leans "no" on disk).
3. Whether closing the lid should lock the screen, given that locking does not stop work in progress.

**Done when:** A spec is approved and an implementation plan exists for a minimal, well-scoped settings model that maps cleanly onto the existing `AwakeController` / `LidCloseController` boundary without breaking the one-click menu bar UX.

## SPEC

[spec.md](./spec.md) — opt-in lid-close prevention, display-sleep / lock-screen / sound checkboxes in the right-click menu, persisted via `UserDefaults`, with live coordinator reconciliation while on.

## FILES

- `docs/scratch.md` — original musing prompting the task
- `docs/feat/20260424192541-merge-fermatta-caffeine/spec.md` — current one-toggle behavior reference
- `docs/feat/20260425200131-lid-event-sounds/spec.md` — current lid-event sound behavior reference
- `Sources/CocaineCore/PreferencesStore.swift` — planned settings store (UserDefaults-backed observable)
- `Sources/CocaineCore/ScreenLocker.swift` — planned `ScreenLocking` protocol + concrete impl
- `Sources/CocaineCore/LidCloseLockResponder.swift` — planned lid-close lock responder
- `Sources/CocaineCore/AppState.swift` — adds `recordErrorWhileActive(_:)` for live-reconciliation failures
- `Sources/CocaineCore/AwakeController.swift` — adds `enable(preventDisplaySleep:)` + `setPreventDisplaySleep(_:)`
- `Sources/CocaineCore/AppCoordinator.swift` — accepts `PreferencesProviding`, conditional helper, live reconciliation
- `Sources/CocaineCore/LidEventSoundController.swift` — gates sounds on `playLidEventSounds`
- `Sources/CocaineCore/LidCloseController.swift` — current lid-close prevention boundary (untouched)
- `Sources/Cocaine/AppDelegate.swift` — wires prefs, screen locker, lock responder
- `Sources/Cocaine/MenuBarController.swift` — extended menu with checkbox items + confirmation alert
- `Tests/CocaineCoreTests/PreferencesStoreTests.swift` — planned defaults/round-trip/publishing tests
- `Tests/CocaineCoreTests/LidCloseLockResponderTests.swift` — planned gating-matrix tests
- `Tests/CocaineCoreTests/AppStateTests.swift` — extended with `recordErrorWhileActive` test
- `Tests/CocaineCoreTests/AwakeControllerTests.swift` — extended with display-flag tests
- `Tests/CocaineCoreTests/AppCoordinatorTests.swift` — extended with prefs-aware + reconciliation tests
- `Tests/CocaineCoreTests/LidEventSoundControllerTests.swift` — extended with sound-pref gating tests
- `README.md` — documents new preferences, defaults, and upgrade note

## PLAN

**Plan:** [plan.md](./plan.md)

**Cursor:** Task 4 — LidEventSoundController gates sounds on preferences

**Status:** in_progress

## LOG

### 2026-04-25 23:29 — Task memory created

- Why: User raised settings ideas in `docs/scratch.md` that change behavior and need a design before implementation.
- How: Created this task ledger after confirming no existing task covers configurable lid-close behavior; the prior tasks covered initial keep-awake and lid event sounds only.

### 2026-04-25 23:54 — Spec approved and committed

- Why: Brainstorming converged on an opt-in settings model that splits the click toggle from lid-close prevention and adds lock-screen, display-sleep, and sound preferences.
- How: Wrote `spec.md` covering UX, architecture, state model, on/off and live reconciliation flows, error handling, testing, risks, and rejected alternatives. Committed as `0ec5e23`.
- Decision: Default `preventLidCloseSleep` to OFF (intentional safety regression vs. today); default `lockScreenOnLidClose` to ON; reconcile live via `runTransition` busy-guard; auto-revert preferences on failed live engagement.

### 2026-04-26 00:05 — Implementation plan generated

- Why: Spec approved and ready for executable bite-sized tasks.
- How: Wrote `plan.md` with 9 tasks covering `PreferencesStore`, `AwakeController` refactor, `AppState.recordErrorWhileActive`, `AppCoordinator` reconciliation, `LidEventSoundController` gating, `ScreenLocker` + `LidCloseLockResponder`, `AppDelegate` wiring, `MenuBarController` checkbox menu + confirmation alert, README docs, and final verification. Self-reviewed against the spec, fixed three issues inline (dead code in screen-locker fallback, ambiguous live-reconciliation isActive handling, missing construction-order note for the lid-event consumers).
- Decision: Use `dlopen`/`dlsym` for `SACLockScreenImmediate` with a `CGSession -suspend` fallback to keep `Package.swift` free of private framework links.

### 2026-04-26 00:08 — Task 1 PreferencesStore foundation

- Why: Add the persisted preferences seam needed by later settings tasks while keeping current consumers untouched until their planned updates.
- How: Added `Sources/CocaineCore/PreferencesStore.swift` with `PreferencesSnapshot`, `PreferencesProviding`, and a `UserDefaults`-backed observable `PreferencesStore`; added `Tests/CocaineCoreTests/PreferencesStoreTests.swift` for spec defaults, round-tripping, snapshots, and Combine publishing. TDD evidence: `swift test --filter PreferencesStoreTests 2>&1 | tail -30` failed first because `PreferencesStore` was missing, then `swift test --filter PreferencesStoreTests 2>&1 | tail -20` passed 4 tests, and `swift test 2>&1 | tail -10` passed 48 tests. Commit: `ff0fa8c`.

### 2026-04-26 00:18 — Task 2 AwakeController display flag and live reconciliation

- Why: Split ordinary no-idle assertion handling from optional display-sleep prevention so future preference changes can be applied while Cocaine remains active.
- How: Updated Sources/CocaineCore/AwakeController.swift with system/display assertion IDs, enable(preventDisplaySleep:), rollback on partial enable failure, and setPreventDisplaySleep(_:) reconciliation; extended Tests/CocaineCoreTests/AwakeControllerTests.swift with 6 display-flag/reconciliation tests and adapted the existing release-order expectation to the new display-first disable path. TDD evidence: swift test --filter AwakeControllerTests 2>&1 | tail -30 failed first on missing enable(preventDisplaySleep:) and setPreventDisplaySleep(_:), then swift test --filter AwakeControllerTests 2>&1 | tail -20 passed 10 tests, and swift test 2>&1 | tail -10 passed 54 tests. Commit: 7690d06.
- Decision: Release the display assertion before the no-idle assertion during disable so live display toggling and full disable share the same display-first cleanup order.

### 2026-04-26 00:44 — Task 3 AppCoordinator preferences and live reconciliation

- Why: Make activation honor persisted display/lid-close preferences and keep the app visibly active when only a live reconciliation path fails.
- How: Added `AppState.recordErrorWhileActive(_:)` in `Sources/CocaineCore/AppState.swift` with coverage in `Tests/CocaineCoreTests/AppStateTests.swift`; widened `AwakeControlling`, injected `PreferencesProviding`, made lid-close engagement conditional/session-scoped, added `setPreventDisplaySleep(_:)` and `setPreventLidCloseSleep(_:)`, and expanded `Tests/CocaineCoreTests/AppCoordinatorTests.swift` with fake preferences plus preference/reconciliation coverage. Evidence: `swift test --filter AppStateTests 2>&1 | tail -20` passed 8 tests; `swift test --filter AppCoordinatorTests 2>&1 | tail -20` passed 18 tests; `swift test 2>&1 | tail -10` passed 63 tests. Commits: `bfecf32`, `93fcabe`.
- Decision: Added a temporary backward-compatible coordinator convenience initializer using `PreferencesStore()` so the app target keeps building until the planned app wiring task injects the shared store.
