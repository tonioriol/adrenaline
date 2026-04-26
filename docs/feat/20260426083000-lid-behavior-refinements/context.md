---
status: brainstorming
spec: ./spec.md
plan: ./plan.md
---

## TASK

Refine Cocaine's right-click menu and behavior based on real-use feedback after the lid-behavior-settings feature shipped:

1. The right-click menu closes when a checkbox is toggled — it should stay open so multiple settings can be flipped without reopening it.
2. "Play lid event sounds" should only have effect when "Prevent sleep with lid closed" is enabled (today it plays whenever Cocaine is on).
3. "Lock screen when lid closes" should be a standalone option, not gated on "Prevent sleep with lid closed".
4. Decide how (or whether) to expose disk-sleep prevention.
5. Add a "Launch at login" checkbox.

## SPEC

[spec.md](./spec.md) — Refine right-click menu behavior, remove forced lock-screen UI, couple lid sounds to lid-close prevention, remove helper repair menu item, skip disk sleep, and add Launch at Login.

## FILES

- [docs/scratch.md](../../scratch.md) — original feedback bullets driving this round
- [docs/feat/20260425232900-lid-behavior-settings/spec.md](../20260425232900-lid-behavior-settings/spec.md) — preceding spec being refined
- [Sources/Cocaine/MenuBarController.swift](../../../Sources/Cocaine/MenuBarController.swift) — menu UI to update
- [Sources/CocaineCore/PreferencesStore.swift](../../../Sources/CocaineCore/PreferencesStore.swift) — preferences to extend
- [Sources/CocaineCore/LidEventSoundController.swift](../../../Sources/CocaineCore/LidEventSoundController.swift) — sound gating logic
- [Sources/CocaineCore/LaunchAtLoginController.swift](../../../Sources/CocaineCore/LaunchAtLoginController.swift) — planned login-item state and registration controller
- [Sources/Cocaine/CheckboxMenuItemView.swift](../../../Sources/Cocaine/CheckboxMenuItemView.swift) — planned non-dismissing checkbox row view
- [Sources/Cocaine/AppDelegate.swift](../../../Sources/Cocaine/AppDelegate.swift) — app wiring; forced lock responder removed in Task 1, launch-at-login wiring planned
- [README.md](../../../README.md) — behavior documentation to update
- Deleted in Task 1: `Sources/CocaineCore/ScreenLocker.swift`, `Sources/CocaineCore/LidCloseLockResponder.swift`, `Tests/CocaineCoreTests/LidCloseLockResponderTests.swift`

## PLAN

[plan.md](./plan.md) — Six-task implementation plan covering forced lock removal, sound gating, Launch at Login, non-dismissing menu rows, README updates, and final verification.

Cursor: Task 6 — Final verification and task record update.

## LOG

### 2026-04-26 08:30 — Task memory created

Captured user feedback bullets from `docs/scratch.md`. Beginning brainstorming pass to clarify ambiguous behavioral semantics (lock-screen independence, disk sleep, launch-at-login defaults) before writing spec.

### 2026-04-26 09:18 — Spec approved and committed

User approved the written refinement spec. Final design keeps Cocaine's core system-awake behavior intact, keeps `Prevent display sleep` as a flat global setting, removes the separate lock-screen feature, keeps the existing first-enable warning on `Prevent sleep with lid closed`, gates lid sounds on lid-close prevention, removes `Repair / Install Helper`, skips disk-sleep controls, and adds `Launch at login` backed by actual macOS login-item state. Spec committed in `1e4db18`.

### 2026-04-26 09:23 — Implementation plan generated

Generated `plan.md` with six implementation tasks: remove forced lock-screen feature wiring and tests, gate lid sounds on lid-close prevention, add a testable Launch at Login controller, refactor menu preference rows to custom non-dismissing checkbox views, update README behavior docs, and run final verification plus task record update. Plan is ready for subagent-driven execution; user preference is to delegate implementer subtasks to GPT-5.5 Low for speed.

### 2026-04-26 09:26 — Task 1 removed forced lid-close locking

Removed forced lock-screen wiring from `Sources/Cocaine/AppDelegate.swift` and deleted `Sources/CocaineCore/ScreenLocker.swift`, `Sources/CocaineCore/LidCloseLockResponder.swift`, and `Tests/CocaineCoreTests/LidCloseLockResponderTests.swift`. Verification: `swift test --filter LidCloseLockResponderTests` PASS before deletion (7 tests); `rg -n "LidCloseLockResponder|ScreenLocker|ScreenLocking|LoginFrameworkScreenLocker" Sources Tests` PASS with no matches after deletion; `swift build` PASS. Commit SHA: 75a640e.

### 2026-04-26 09:33 — Task 2 gated lid event sounds on lid-close prevention

Updated `Sources/CocaineCore/LidEventSoundController.swift` so lid event sounds require active app state, started monitoring, non-duplicate lid state, `preventLidCloseSleep == true`, and `playLidEventSounds == true`; `lastHandledState` remains assigned before preference gates so duplicate suppression still applies while muted. Updated `Tests/CocaineCoreTests/LidEventSoundControllerTests.swift` positive playback coverage to opt into lid-close prevention and added regression coverage for `preventLidCloseSleep == false` silencing events even when lid event sounds are enabled. Verification: `swift test --filter LidEventSoundControllerTests/testPreventLidCloseSleepOffSilencesEventsEvenWhenSoundsEnabled` RED before implementation (1 expected assertion failure), then `swift test --filter LidEventSoundControllerTests` PASS after implementation (11 tests, 0 failures). Commit SHA: 278382a.

### 2026-04-26 09:40 — Task 3 added Launch at Login controller

Created `Sources/CocaineCore/LaunchAtLoginController.swift` with `LaunchAtLoginStatus`, `LoginItemServicing`, `MainAppLoginItemService`, `LaunchAtLoginControlling`, and an injected `LaunchAtLoginController` around `SMAppService.mainApp`. Added `Tests/CocaineCoreTests/LaunchAtLoginControllerTests.swift` with fake-service coverage for status/isEnabled mapping, register/unregister behavior, idempotency, disabling from `requiresApproval`, no-op disabled/unavailable disables, and register/unregister error propagation. Verification: `swift test --filter LaunchAtLoginControllerTests` RED before implementation with expected missing `LoginItemServicing`, `LaunchAtLoginStatus`, and `LaunchAtLoginController` compile errors; `swift test --filter LaunchAtLoginControllerTests` PASS after implementation (10 tests, 0 failures). SDK notes: local SDK includes `SMAppService.Status.notFound`, mapped to `.unavailable`; adjusted the defaulted controller initializer to instantiate `MainAppLoginItemService()` inside the `@MainActor` initializer body to satisfy actor isolation. Commit SHA: 889982c.

### 2026-04-26 09:49 — Task 4 refactored menu checkbox rows

Created `Sources/Cocaine/CheckboxMenuItemView.swift` for custom `NSMenuItem.view` checkbox rows, replaced preference rows in `Sources/Cocaine/MenuBarController.swift` so checkbox toggles refresh visible row state without dismissing the open menu, removed the lock-screen and helper-repair menu rows/actions, disabled `Play lid event sounds` while lid-close prevention is off, added a local `Launch at login` row/error message backed by `LaunchAtLoginControlling`, and wired `LaunchAtLoginController()` through `Sources/Cocaine/AppDelegate.swift`. Verification: `swift build --product Cocaine` PASS; `rg -n "Lock screen when lid closes|Repair / Install Helper|toggleLockScreenOnLidClose|repairHelper" Sources/Cocaine Sources/CocaineCore` PASS with no output. Commit SHA: d9e9924.

### 2026-04-26 09:56 — Task 5 updated README behavior docs

Updated `README.md` to describe current user-facing behavior: system sleep prevention via public IOKit assertions, optional display sleep prevention, opt-in lid-close sleep prevention, lid event sounds gated by lid-close prevention, Launch at Login, non-dismissing checkbox preference rows, and native macOS sleep/lock behavior when lid-close prevention or display-sleep prevention is off. Removed stale documentation references to forced lid-close lock behavior and helper repair menu UI. Verification: `rg -n "Lock screen when lid closes|Repair / Install Helper|screen locking on lid close" README.md` PASS with no output. Commit SHA: 7b8508f.

### 2026-04-26 10:02 — Task 6 final verification recorded

Verified the completed lid behavior refinements from HEAD `e018b41`. `make test` PASS: 79 XCTest tests executed with 0 failures, followed by Swift Testing reporting 0 tests in 0 suites passed. `make app` PASS: debug build completed, `build/Cocaine.app` was recreated, helper and app binaries were copied into the bundle, and codesigning completed. Scoped stale-reference check `rg -n "Lock screen when lid closes|Repair / Install Helper|LidCloseLockResponder|ScreenLocker|LoginFrameworkScreenLocker|toggleLockScreenOnLidClose|repairHelper" Sources Tests README.md docs/feat/20260426083000-lid-behavior-refinements` returned matches only in this task's spec/plan/context history and no matches in `Sources`, `Tests`, or `README.md`; no production, test, or user-facing stale references were found. Final pre-record git status contained only pre-existing untracked `.gitkeep`, `.vscode/`, and `docs/scratch.md`. Manual app checks were not performed in this headless verification pass and remain pending for a local GUI run. Verification record commit SHA: pending.
