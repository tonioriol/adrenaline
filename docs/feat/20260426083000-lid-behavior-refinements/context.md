---
status: brainstorming
spec: null
plan: null
---

## TASK

Refine Cocaine's right-click menu and behavior based on real-use feedback after the lid-behavior-settings feature shipped:

1. The right-click menu closes when a checkbox is toggled — it should stay open so multiple settings can be flipped without reopening it.
2. "Play lid event sounds" should only have effect when "Prevent sleep with lid closed" is enabled (today it plays whenever Cocaine is on).
3. "Lock screen when lid closes" should be a standalone option, not gated on "Prevent sleep with lid closed".
4. Decide how (or whether) to expose disk-sleep prevention.
5. Add a "Launch at login" checkbox.

## SPEC

(pending)

## FILES

- [docs/scratch.md](../../scratch.md) — original feedback bullets driving this round
- [docs/feat/20260425232900-lid-behavior-settings/spec.md](../20260425232900-lid-behavior-settings/spec.md) — preceding spec being refined
- [Sources/Cocaine/MenuBarController.swift](../../../Sources/Cocaine/MenuBarController.swift) — menu UI to update
- [Sources/CocaineCore/PreferencesStore.swift](../../../Sources/CocaineCore/PreferencesStore.swift) — preferences to extend
- [Sources/CocaineCore/LidEventSoundController.swift](../../../Sources/CocaineCore/LidEventSoundController.swift) — sound gating logic
- [Sources/CocaineCore/LidCloseLockResponder.swift](../../../Sources/CocaineCore/LidCloseLockResponder.swift) — lock gating logic
- [Sources/Cocaine/AppDelegate.swift](../../../Sources/Cocaine/AppDelegate.swift) — wiring + launch-at-login service registration

## PLAN

(pending)

## LOG

### 2026-04-26 08:30 — Task memory created

Captured user feedback bullets from `docs/scratch.md`. Beginning brainstorming pass to clarify ambiguous behavioral semantics (lock-screen independence, disk sleep, launch-at-login defaults) before writing spec.
