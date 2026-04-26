---
title: "Configurable lid-close behavior settings"
status: done
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
- `Sources/CocaineCore/PreferencesStore.swift` — persisted settings store (`UserDefaults`-backed observable)
- `Sources/CocaineCore/ScreenLocker.swift` — `ScreenLocking` protocol + concrete lock implementation with private-symbol + fallback strategy
- `Sources/CocaineCore/LidCloseLockResponder.swift` — lid-close lock responder chained onto lid-state events
- `Sources/CocaineCore/AppState.swift` — adds `recordErrorWhileActive(_:)` for live-reconciliation failures
- `Sources/CocaineCore/AwakeController.swift` — adds `enable(preventDisplaySleep:)` + `setPreventDisplaySleep(_:)`
- `Sources/CocaineCore/AppCoordinator.swift` — accepts `PreferencesProviding`, conditional helper, live reconciliation
- `Sources/CocaineCore/LidEventSoundController.swift` — gates sounds on `playLidEventSounds`
- `Sources/CocaineCore/LidCloseController.swift` — current lid-close prevention boundary (untouched)
- `Sources/Cocaine/AppDelegate.swift` — wires prefs, screen locker, lock responder
- `Sources/Cocaine/MenuBarController.swift` — extended menu with checkbox items + confirmation alert
- `Tests/CocaineCoreTests/PreferencesStoreTests.swift` — defaults/round-trip/publishing tests
- `Tests/CocaineCoreTests/LidCloseLockResponderTests.swift` — gating matrix + callback chaining tests
- `Tests/CocaineCoreTests/AppStateTests.swift` — extended with `recordErrorWhileActive` test
- `Tests/CocaineCoreTests/AwakeControllerTests.swift` — extended with display-flag tests
- `Tests/CocaineCoreTests/AppCoordinatorTests.swift` — extended with prefs-aware + reconciliation tests
- `Tests/CocaineCoreTests/LidEventSoundControllerTests.swift` — extended with sound-pref gating tests
- `README.md` — documents new preferences, defaults, and upgrade note

## PLAN

**Plan:** [plan.md](./plan.md)

**Cursor:** all tasks complete

**Status:** complete_with_manual_followup

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

### 2026-04-26 01:02 — Task 4 LidEventSoundController preference gate

- Why: Let the persisted sound preference silence lid-close/open feedback while preserving active-state monitoring and duplicate suppression.
- How: Updated Sources/CocaineCore/LidEventSoundController.swift to accept PreferencesProviding, gate playback on playLidEventSounds after recording lastHandledState, and keep a three-argument convenience initializer for existing app wiring; extended Tests/CocaineCoreTests/LidEventSoundControllerTests.swift with FakePreferencesStore and sound-preference gating coverage while injecting preferences into all existing controller constructions. Evidence: swift test --filter LidEventSoundControllerTests 2>&1 | tail -20 first failed with extra argument 'preferences' in call, then passed 9 tests; swift test 2>&1 | tail -10 passed 65 tests. Commit: 858ef15.
- Decision: Added a transitional convenience initializer backed by PreferencesStore() so the executable target keeps building until the planned app wiring task injects the shared preferences store and removes the shim.

## LOG: Task 4 review fix — muted-duplicate regression test

- Added `testMutedDuplicateLidStateDoesNotReplayAfterSoundsReenabled` to cover the muted duplicate lid-state semantic: a lid state handled while sounds are disabled must not replay when sounds are re-enabled and the same state is emitted again.
- Verification passed: `swift test --filter LidEventSoundControllerTests 2>&1 | tail -20` executed 10 tests with 0 failures; `swift test 2>&1 | tail -10` executed 66 tests with 0 failures.
- Committed the test-only fix as `07327cd` (`test: cover muted-duplicate suppression in lid sound controller`).

### 2026-04-26 01:13 — Task 5 ScreenLocker and lid-close lock responder

- Why: Add the lock-screen side effect behind explicit active-state and lid-close preferences, keeping lock failures best-effort and separate from sleep-prevention state.
- How: Added `Sources/CocaineCore/ScreenLocker.swift` with `ScreenLocking`, `ScreenLockerError`, and `LoginFrameworkScreenLocker`; added `Sources/CocaineCore/LidCloseLockResponder.swift` to chain onto `LidStateMonitoring.onLidStateChange` and lock only on closed events when active, lid-close prevention is enabled, and lock-on-close is enabled; added `Tests/CocaineCoreTests/LidCloseLockResponderTests.swift` with 6 gating/error tests. Evidence: `swift test --filter LidCloseLockResponderTests 2>&1 | tail -20` first failed because `ScreenLocking`/`LidCloseLockResponder` were missing, then passed 6 tests; `swift test 2>&1 | tail -10` passed 72 tests. Commit: `b6511fd`.
- Decision: Load private `SACLockScreenImmediate` via `dlopen`/`dlsym` without linking the private framework, and fall back to `CGSession -suspend` so screen locking remains best-effort without requiring AppleScript automation permissions.

## LOG: Task 5 review fix — screen-lock fallback hardening and callback chaining

- Accepted review fixes for Task 5: hardened `LoginFrameworkScreenLocker` fallback execution to try executable `CGSession -suspend` first and `/usr/bin/osascript -e 'tell application "loginwindow" to «event aevtrlck»'` second; made `lock()` inspect `SACLockScreenImmediate` return status and fall back on nonzero status; added missing-symbol logging plus `dlclose(handle)` only on the missing-symbol branch; removed unused `Combine` import from `LidCloseLockResponder`; added callback chaining coverage verifying the prior lid-state callback receives `.closed` before the responder lock path runs.
- Verification passed: `swift test --filter LidCloseLockResponderTests 2>&1 | tail -20` executed 7 tests with 0 failures; `swift test 2>&1 | tail -10` executed 73 tests with 0 failures.
- Committed the code/test fix as `38b5ac9` (`fix: harden screen locker fallback and callback coverage`).

### 2026-04-26 01:36 — Task 6/7 app wiring and preference menu UI

- Why: App wiring now injects one shared `PreferencesStore` and the menu bar exposes the new preference controls.
- How: Updated `Sources/Cocaine/AppDelegate.swift`, `Sources/Cocaine/MenuBarController.swift`, `Sources/CocaineCore/AppCoordinator.swift`, and `Sources/CocaineCore/LidEventSoundController.swift` to wire shared preferences, screen locking, lock response, checkbox menu state, live preference routing, and the lid-close confirmation alert; removed the two transitional convenience initializers from `AppCoordinator` and `LidEventSoundController`. Verification: `grep -n "convenience init" Sources/CocaineCore/*.swift ; echo "exit=$?"` found no matches and printed `exit=1`; `swift build 2>&1 | tail -20` passed; `make app 2>&1 | tail -10` passed; `swift test 2>&1 | tail -10` passed with 73 tests and 0 failures. Commit: `2f6441b`.
- Decision: Task 6 and Task 7 were executed together so the executable target never sat in a broken intermediate state.

### 2026-04-26 01:51 — Task 6/7 review fix: menu tooltip and warning rollback

- Accepted code-quality review fixes for the combined Task 6/7 app wiring + menu UI change: `MenuBarController.bindState()` now re-renders when `preventLidCloseSleep` changes so the active tooltip stays in sync, and `togglePreventLidCloseSleep()` clears `lidClosePreventionConfirmed` if a live enable attempt rolls `preventLidCloseSleep` back to false.
- Verification passed: `swift build 2>&1 | tail -20` passed; `make app 2>&1 | tail -10` passed; `swift test 2>&1 | tail -10` executed 73 tests with 0 failures.
- Committed the MenuBarController-only fix as `a100841` (`fix: keep lid-close warning and tooltip in sync`).

### 2026-04-26 01:55 — Task 8 README behavior documentation

- Why: The new settings model changes user-visible defaults and separates lid-close prevention from the main on/off toggle, so the README needed to describe the new behavior and upgrade impact.
- How: Replaced `README.md` with updated Safety, Run, Behavior, preference defaults, helper authorization, repair/install helper, and upgrade-note text. Verification: `git diff -- README.md | head -80` showed the expected README rewrite before commit.
- Commit: `44a94e3` (`docs: describe lid-close behavior preferences`).

### 2026-04-26 01:57 — Task 9 final verification

- Why: Confirm the completed lid-behavior settings work builds, tests, launches, and cleans up before leaving only hardware-dependent manual checks.
- How: Ran `make clean && make test 2>&1 | tail -20` (73 XCTest tests, 0 failures), `make app 2>&1 | tail -10` (app bundle copied and signed), `open build/Cocaine.app && sleep 2 && pgrep -lf Cocaine.app/Contents/MacOS/Cocaine` (smoke launch printed PIDs including `build/Cocaine.app/Contents/MacOS/Cocaine`), `pkill -f 'Cocaine.app/Contents/MacOS/Cocaine' && sleep 1 && pgrep -lf Cocaine.app/Contents/MacOS/Cocaine ; echo "exit=$?"` (`exit=1`, no matching process), and `pmset -g assertions | grep -i cocaine ; echo "exit=$?"` (`exit=1`, no Cocaine-named assertion).
- Decision: Automated verification is complete; manual physical-hardware validation remains pending for right-click menu defaults, confirmation-alert behavior, lid-close lock/unlock behavior, SleepDisabled transitions, relaunch semantics, and normal sleep when lid-close prevention is off.

### 2026-04-26 02:09 — Final review fix: live lid-close disable stays active on failure

- Accepted final review item: the live disable path for lid-close prevention must not mark the app inactive while ordinary awake assertions are still held.
- How: Updated `Sources/CocaineCore/AppCoordinator.swift` so successful live disable verifies `lidCloseController.status() == false` before clearing session engagement. Disable throws or status-still-active failures now call `recordErrorWhileActive()` and preserve the active UI/error state instead of clearing active state.
- Tests: Added two `Tests/CocaineCoreTests/AppCoordinatorTests.swift` cases covering disable failure and disable-success/status-still-active behavior, including preference remains false, ordinary awake remains enabled, and UI remains active-with-error.
- Verification passed: `swift test --filter AppCoordinatorTests 2>&1 | tail -20` executed 20 tests with 0 failures; `swift test 2>&1 | tail -10` executed 75 tests with 0 failures.
- Commit: `f2ee147` (`fix: keep live lid-close disable failures active`).

### 2026-04-26 02:12 — Implementation session complete

- Why: All planned feature tasks, review fixes, documentation work, and automated verification are complete for the configurable lid-behavior settings release.
- How: Delivered Tasks 1–9 plus review follow-ups across commits `ff0fa8c`, `7690d06`, `bfecf32`, `93fcabe`, `858ef15`, `07327cd`, `b6511fd`, `38b5ac9`, `2f6441b`, `a100841`, `44a94e3`, and `f2ee147`; completed automated verification with `make clean && make test` (75 XCTest tests), `make app`, smoke-launch of [`build/Cocaine.app`](build/Cocaine.app), clean process shutdown, and no lingering Cocaine-named `pmset` assertions.
- Decision: Treat the implementation as complete for code and automated verification; the remaining follow-up is physical-hardware/manual validation of actual lid-close behavior, confirmation alerts, and lock/unlock behavior on a MacBook.

### 2026-04-26 02:14 — Local merge option completed

- Why: The user selected the local-merge completion path after implementation and verification were finished.
- How: Confirmed the completed work was already on [`main`](.git/HEAD) rather than a separate feature branch, with green tests from [`make test`](Makefile:1). Because the implementation commits were already on the target branch, no additional `git merge` step or branch deletion was needed. No separate worktree cleanup was required.
- Decision: Treat the requested local merge as a no-op integration on the current branch; keep the remaining follow-up limited to manual MacBook lid-close validation outside this session.
