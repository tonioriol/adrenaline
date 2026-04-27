---
status: active
spec: ./spec.md
plan: ./plan.md
---

## TASK

Refine Insomnia's right-click menu and behavior based on real-use feedback after the lid-behavior-settings feature shipped:

1. The right-click menu closes when a checkbox is toggled — it should stay open so multiple settings can be flipped without reopening it.
2. "Play lid event sounds" should only have effect when "Prevent sleep with lid closed" is enabled (today it plays whenever Insomnia is on).
3. "Lock screen when lid closes" should be a standalone option, not gated on "Prevent sleep with lid closed".
4. Decide how (or whether) to expose disk-sleep prevention.
5. Add a "Launch at login" checkbox.

## SPEC

[spec.md](./spec.md) — Refine right-click menu behavior, remove forced lock-screen UI, couple lid sounds to lid-close prevention, remove helper repair menu item, skip disk sleep, and add Launch at Login.

## FILES

- [docs/scratch.md](../../scratch.md) — original feedback bullets driving this round
- [docs/feat/20260425232900-lid-behavior-settings/spec.md](../20260425232900-lid-behavior-settings/spec.md) — preceding spec being refined
- [Sources/Insomnia/MenuBarController.swift](../../../Sources/Insomnia/MenuBarController.swift) — menu UI to update
- [Sources/InsomniaCore/PreferencesStore.swift](../../../Sources/InsomniaCore/PreferencesStore.swift) — preferences to extend
- [Sources/InsomniaCore/LidEventSoundController.swift](../../../Sources/InsomniaCore/LidEventSoundController.swift) — sound gating logic
- [Sources/InsomniaCore/LaunchAtLoginController.swift](../../../Sources/InsomniaCore/LaunchAtLoginController.swift) — planned login-item state and registration controller
- [Sources/Insomnia/CheckboxMenuItemView.swift](../../../Sources/Insomnia/CheckboxMenuItemView.swift) — planned non-dismissing checkbox row view
- [Sources/Insomnia/AppDelegate.swift](../../../Sources/Insomnia/AppDelegate.swift) — app wiring; launch-at-login wired and lock responder restored with computed behavior
- [Sources/InsomniaCore/LidCloseLockResponder.swift](../../../Sources/InsomniaCore/LidCloseLockResponder.swift) — computed lock-on-lid-close behavior, now derived from display + lid-close preferences
- [Sources/InsomniaCore/ScreenLocker.swift](../../../Sources/InsomniaCore/ScreenLocker.swift) — restored lock implementation used when lid-close prevention keeps system awake
- [Sources/InsomniaCore/PreferenceMenuRows.swift](../../../Sources/InsomniaCore/PreferenceMenuRows.swift) — menu row model, cleaned up to remove explicit lock row contamination
- [README.md](../../../README.md) — behavior documentation to update
- [Tests/InsomniaCoreTests/LidCloseLockResponderTests.swift](../../../Tests/InsomniaCoreTests/LidCloseLockResponderTests.swift) — computed lock behavior tests
- [Tests/InsomniaCoreTests/PreferenceMenuRowsTests.swift](../../../Tests/InsomniaCoreTests/PreferenceMenuRowsTests.swift) — menu row model tests after contamination cleanup

## PLAN

[plan.md](./plan.md) — Six-task implementation plan covering forced lock removal, sound gating, Launch at Login, non-dismissing menu rows, README updates, and final verification.

Cursor: follow-up bugfixes after shipped refinement work; latest state matches computed lock matrix and cleaned menu model.

## LOG

### 2026-04-26 08:30 — Task memory created

Captured user feedback bullets from `docs/scratch.md`. Beginning brainstorming pass to clarify ambiguous behavioral semantics (lock-screen independence, disk sleep, launch-at-login defaults) before writing spec.

### 2026-04-26 09:18 — Spec approved and committed

User approved the written refinement spec. Final design keeps Insomnia's core system-awake behavior intact, keeps `Prevent display sleep` as a flat global setting, removes the separate lock-screen feature, keeps the existing first-enable warning on `Prevent sleep with lid closed`, gates lid sounds on lid-close prevention, removes `Repair / Install Helper`, skips disk-sleep controls, and adds `Launch at login` backed by actual macOS login-item state. Spec committed in `1e4db18`.

### 2026-04-26 09:23 — Implementation plan generated

Generated `plan.md` with six implementation tasks: remove forced lock-screen feature wiring and tests, gate lid sounds on lid-close prevention, add a testable Launch at Login controller, refactor menu preference rows to custom non-dismissing checkbox views, update README behavior docs, and run final verification plus task record update. Plan is ready for subagent-driven execution; user preference is to delegate implementer subtasks to GPT-5.5 Low for speed.

### 2026-04-26 09:26 — Task 1 removed forced lid-close locking

Removed forced lock-screen wiring from `Sources/Insomnia/AppDelegate.swift` and deleted `Sources/InsomniaCore/ScreenLocker.swift`, `Sources/InsomniaCore/LidCloseLockResponder.swift`, and `Tests/InsomniaCoreTests/LidCloseLockResponderTests.swift`. Verification: `swift test --filter LidCloseLockResponderTests` PASS before deletion (7 tests); `rg -n "LidCloseLockResponder|ScreenLocker|ScreenLocking|LoginFrameworkScreenLocker" Sources Tests` PASS with no matches after deletion; `swift build` PASS. Commit SHA: 75a640e.

### 2026-04-26 09:33 — Task 2 gated lid event sounds on lid-close prevention

Updated `Sources/InsomniaCore/LidEventSoundController.swift` so lid event sounds require active app state, started monitoring, non-duplicate lid state, `preventLidCloseSleep == true`, and `playLidEventSounds == true`; `lastHandledState` remains assigned before preference gates so duplicate suppression still applies while muted. Updated `Tests/InsomniaCoreTests/LidEventSoundControllerTests.swift` positive playback coverage to opt into lid-close prevention and added regression coverage for `preventLidCloseSleep == false` silencing events even when lid event sounds are enabled. Verification: `swift test --filter LidEventSoundControllerTests/testPreventLidCloseSleepOffSilencesEventsEvenWhenSoundsEnabled` RED before implementation (1 expected assertion failure), then `swift test --filter LidEventSoundControllerTests` PASS after implementation (11 tests, 0 failures). Commit SHA: 278382a.

### 2026-04-26 09:40 — Task 3 added Launch at Login controller

Created `Sources/InsomniaCore/LaunchAtLoginController.swift` with `LaunchAtLoginStatus`, `LoginItemServicing`, `MainAppLoginItemService`, `LaunchAtLoginControlling`, and an injected `LaunchAtLoginController` around `SMAppService.mainApp`. Added `Tests/InsomniaCoreTests/LaunchAtLoginControllerTests.swift` with fake-service coverage for status/isEnabled mapping, register/unregister behavior, idempotency, disabling from `requiresApproval`, no-op disabled/unavailable disables, and register/unregister error propagation. Verification: `swift test --filter LaunchAtLoginControllerTests` RED before implementation with expected missing `LoginItemServicing`, `LaunchAtLoginStatus`, and `LaunchAtLoginController` compile errors; `swift test --filter LaunchAtLoginControllerTests` PASS after implementation (10 tests, 0 failures). SDK notes: local SDK includes `SMAppService.Status.notFound`, mapped to `.unavailable`; adjusted the defaulted controller initializer to instantiate `MainAppLoginItemService()` inside the `@MainActor` initializer body to satisfy actor isolation. Commit SHA: 889982c.

### 2026-04-26 09:49 — Task 4 refactored menu checkbox rows

Created `Sources/Insomnia/CheckboxMenuItemView.swift` for custom `NSMenuItem.view` checkbox rows, replaced preference rows in `Sources/Insomnia/MenuBarController.swift` so checkbox toggles refresh visible row state without dismissing the open menu, removed the lock-screen and helper-repair menu rows/actions, disabled `Play lid event sounds` while lid-close prevention is off, added a local `Launch at login` row/error message backed by `LaunchAtLoginControlling`, and wired `LaunchAtLoginController()` through `Sources/Insomnia/AppDelegate.swift`. Verification: `swift build --product Insomnia` PASS; `rg -n "Lock screen when lid closes|Repair / Install Helper|toggleLockScreenOnLidClose|repairHelper" Sources/Insomnia Sources/InsomniaCore` PASS with no output. Commit SHA: d9e9924.

### 2026-04-26 09:56 — Task 5 updated README behavior docs

Updated `README.md` to describe current user-facing behavior: system sleep prevention via public IOKit assertions, optional display sleep prevention, opt-in lid-close sleep prevention, lid event sounds gated by lid-close prevention, Launch at Login, non-dismissing checkbox preference rows, and native macOS sleep/lock behavior when lid-close prevention or display-sleep prevention is off. Removed stale documentation references to forced lid-close lock behavior and helper repair menu UI. Verification: `rg -n "Lock screen when lid closes|Repair / Install Helper|screen locking on lid close" README.md` PASS with no output. Commit SHA: 7b8508f.

### 2026-04-26 10:02 — Task 6 final verification recorded

Verified the completed lid behavior refinements from HEAD `e018b41`. `make test` PASS: 79 XCTest tests executed with 0 failures, followed by Swift Testing reporting 0 tests in 0 suites passed. `make app` PASS: debug build completed, `build/Insomnia.app` was recreated, helper and app binaries were copied into the bundle, and codesigning completed. Scoped stale-reference check `rg -n "Lock screen when lid closes|Repair / Install Helper|LidCloseLockResponder|ScreenLocker|LoginFrameworkScreenLocker|toggleLockScreenOnLidClose|repairHelper" Sources Tests README.md docs/feat/20260426083000-lid-behavior-refinements` returned matches only in this task's spec/plan/context history and no matches in `Sources`, `Tests`, or `README.md`; no production, test, or user-facing stale references were found. Final pre-record git status contained only pre-existing untracked `.gitkeep`, `.vscode/`, and `docs/scratch.md`. Manual app checks were not performed in this headless verification pass and remain pending for a local GUI run. Verification record commit SHA: cb523f6.

### 2026-04-26 10:11 — Local merge option completed

User selected option 1, merge back to `main` locally. The repository was already on `main`, so there was no feature branch to merge and no branch cleanup to perform. Completion verification had already passed on `main`: `make test` executed 79 XCTest tests with 0 failures, and final review approved the implementation. Remaining untracked files are pre-existing `.gitkeep`, `.vscode/`, and `docs/scratch.md`. Manual GUI checks remain the only follow-up.

### 2026-04-26 10:20 — Reinstall target added and app reinstalled

Added a new `reinstall` target to `Makefile` so the app can be rebuilt, copied into `/Applications/Insomnia.app`, and relaunched in one command. Verified the target shape with `make -n reinstall`, then ran `make test`, `make app`, and `make reinstall`; the installed app relaunched successfully from `/Applications/Insomnia.app/Contents/MacOS/Insomnia`. Commit SHA: `82533a1`.

### 2026-04-26 10:24 — Lid sounds row nested and lid-close label clarified

Updated the menu presentation so `Play lid event sounds` is visually nested under `Prevent system sleep with lid closed`, and widened the row view so the longer lid-close label is not truncated. Also updated `README.md` to use the new lid-close wording. Reinstalled the app after each UI change. Commits: `5e7d000` (nested child row) and `065f477` (renamed lid-close row and README sync).

### 2026-04-26 10:50 — Spurious lid sounds on display dim/wake suppressed

Root cause investigation showed the sound controller treated the first clamshell notification after monitoring start as a real lid transition because `lastHandledState` started as `nil`. Added `currentLidState` to `LidStateMonitoring`, implemented it in `LidStateMonitor` by reading `AppleClamshellState` from `IOPMrootDomain`, and seeded `lastHandledState` on monitor start. Added two regression tests to `LidEventSoundControllerTests` and widened the menu row to 280pt. Verification: 87 tests passed, `make reinstall` succeeded, and the installed app relaunched. Commit SHA: `a935aee`.

### 2026-04-26 11:07 — Computed lid-close lock behavior restored and explicit lock row removed

The user clarified the intended matrix: lock-on-lid-close must be computed from `preventDisplaySleep` and `preventLidCloseSleep`, not exposed as a separate menu preference. Restored `ScreenLocker` / `LidCloseLockResponder` so lid-close prevention can keep the system awake while explicitly locking the screen when `preventDisplaySleep == false`, then removed the mistaken explicit `Lock screen on lid close` menu row/toggle plumbing from `PreferenceMenuRows` and `MenuBarController`. Updated `LidCloseLockResponderTests` and `PreferenceMenuRowsTests` so they assert the agreed computed model instead of the contaminated explicit-toggle model. Final verification: focused `LidCloseLockResponderTests` and `PreferenceMenuRowsTests` passed, full suite reached 90 tests with 0 failures, and `make reinstall` relaunched the installed app. Commits: `64b51fe` (restore computed lock-on-close behavior) and `43828fe` (remove explicit lock row contamination and keep lock computed).
