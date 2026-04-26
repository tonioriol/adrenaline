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

Cursor: Task 2 — Gate lid event sounds on lid-close prevention.

## LOG

### 2026-04-26 08:30 — Task memory created

Captured user feedback bullets from `docs/scratch.md`. Beginning brainstorming pass to clarify ambiguous behavioral semantics (lock-screen independence, disk sleep, launch-at-login defaults) before writing spec.

### 2026-04-26 09:18 — Spec approved and committed

User approved the written refinement spec. Final design keeps Cocaine's core system-awake behavior intact, keeps `Prevent display sleep` as a flat global setting, removes the separate lock-screen feature, keeps the existing first-enable warning on `Prevent sleep with lid closed`, gates lid sounds on lid-close prevention, removes `Repair / Install Helper`, skips disk-sleep controls, and adds `Launch at login` backed by actual macOS login-item state. Spec committed in `1e4db18`.

### 2026-04-26 09:23 — Implementation plan generated

Generated `plan.md` with six implementation tasks: remove forced lock-screen feature wiring and tests, gate lid sounds on lid-close prevention, add a testable Launch at Login controller, refactor menu preference rows to custom non-dismissing checkbox views, update README behavior docs, and run final verification plus task record update. Plan is ready for subagent-driven execution; user preference is to delegate implementer subtasks to GPT-5.5 Low for speed.

### 2026-04-26 09:26 — Task 1 removed forced lid-close locking

Removed forced lock-screen wiring from `Sources/Cocaine/AppDelegate.swift` and deleted `Sources/CocaineCore/ScreenLocker.swift`, `Sources/CocaineCore/LidCloseLockResponder.swift`, and `Tests/CocaineCoreTests/LidCloseLockResponderTests.swift`. Verification: `swift test --filter LidCloseLockResponderTests` PASS before deletion (7 tests); `rg -n "LidCloseLockResponder|ScreenLocker|ScreenLocking|LoginFrameworkScreenLocker" Sources Tests` PASS with no matches after deletion; `swift build` PASS. Commit SHA: 75a640e.
