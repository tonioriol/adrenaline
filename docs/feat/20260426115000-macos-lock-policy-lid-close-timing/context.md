---
title: "Respect macOS lock policy for lid-close timing"
status: active
repos: [cocaine]
tags: [macos, power, security]
related: [20260425232900-lid-behavior-settings, 20260426083000-lid-behavior-refinements]
created: 2026-04-26
---

# Respect macOS lock policy for lid-close timing

## TASK

**Goal:** Make Cocaine's lid-close lock behavior follow the user's macOS lock policy and display-off timer instead of always locking immediately when lid-close sleep prevention keeps the system awake.

The current computed lock path fills the gap where `SleepDisabled = true` prevents macOS from reaching its native sleep/screensaver lock trigger. The requested refinement is to preserve that gap-fill behavior only when macOS itself would require a password, and to delay the gap-fill lock according to the relevant macOS display-off timing rather than firing instantly on lid close.

**Done when:** Cocaine does not force-lock on lid close when macOS Require Password is disabled, and otherwise schedules lid-close locking based on the effective macOS display-off timer for the current power source while preserving existing sleep-prevention and menu behavior.

## SPEC

[spec.md](./spec.md) — design for matching macOS lid-close lock policy by delaying lock until display-off timer plus password delay, and skipping locks when Require Password is disabled.

## FILES

- Sources/CocaineCore/LidCloseLockResponder.swift — existing computed lid-close lock behavior
- Sources/CocaineCore/LidCloseLockScheduler.swift — planned cancellable delayed lock scheduler abstraction
- Sources/CocaineCore/MacOSLockPolicyReader.swift — planned macOS Require Password/display timer policy reader
- Sources/CocaineCore/ScreenLocker.swift — lock implementation used by lid-close responder
- Sources/CocaineCore/PreferencesStore.swift — app preference state that currently controls display and lid behavior
- Sources/CocaineHelper/ApplePowerSettings.swift — existing helper-side macOS power settings access
- Sources/Cocaine/AppDelegate.swift — wires lid event sound and lock responders against one lid monitor
- Sources/Cocaine/MenuBarController.swift — current menu exposes display/lid/sound/login controls but no lock row
- Sources/CocaineCore/PreferenceMenuRows.swift — current preference row model with no standalone lock row
- Tests/CocaineCoreTests/LidCloseLockResponderTests.swift — lock behavior regression tests
- Tests/CocaineCoreTests/MacOSLockPolicyReaderTests.swift — planned policy reader regression tests
- README.md — user-facing behavior table to update after design approval

## PLAN

**Plan:** [plan.md](./plan.md)

**Cursor:** Task 1 — add macOS lock policy reader

**Status:** in_progress

## LOG

### 2026-04-26 11:50 — Task memory created

- Why: The requested behavior changes the security semantics of lid-close locking and depends on macOS settings, so it needs an explicit design record before implementation.
- How: Created this ledger and linked the prior lid behavior tasks that introduced preferences, display-sleep handling, and computed lid-close locking.
- Decision: Treat the change as a refinement of computed lid-close locking rather than a new visible menu preference unless design exploration shows a user-facing control is needed.

### 2026-04-26 11:53 — Current behavior and macOS setting sources identified

- Why: The design needs to preserve the existing computed lock matrix while replacing the immediate lock trigger with macOS-policy-aware timing.
- How: Confirmed `LidCloseLockResponder` currently locks immediately only when Cocaine is active, lid-close prevention is enabled, and display-sleep prevention is off. `ScreenLocker` uses `SACLockScreenImmediate` with command fallbacks. The menu has no standalone lock row. On this Mac, `pmset -g custom` reports `displaysleep = 1` on battery and `displaysleep = 5` on AC, and `defaults read com.apple.screensaver` reports `askForPassword = 1`, `askForPasswordDelay = 0`. The backing power-management plist exposes `Display Sleep Timer` entries under `Battery Power` and `AC Power`.
- Decision: Model the new design around a focused macOS policy reader that supplies lock-enabled state plus current display-off delay, and keep the responder as the place that schedules/cancels the best-effort lock.

### 2026-04-26 12:01 — Lock timing clarified as full macOS lock timing

- Why: A display-off-only delay would still be surprising when the macOS Require Password setting uses a non-immediate delay.
- How: User selected matching macOS as the guiding rule: lock after display-off timer plus Require Password delay, and do not lock at all when Require Password is Never.
- Decision: The spec should define Cocaine's lid-close lock as a best-effort emulation of when macOS would actually require a password, not merely when the display would turn off.

### 2026-04-26 12:05 — Spec written for macOS-matching lid-close lock timing

- Why: User approved the plain-English design: check macOS settings on lid close, skip locking when Require Password is Never, otherwise delay by current display-off timer plus password delay, and cancel on lid reopen.
- How: Wrote `spec.md` covering user-facing behavior, policy reading, delayed responder scheduling, cancellation/recheck rules, tests, docs, risks, and rejected alternatives.
- Decision: Keep the feature invisible in the menu and preserve the current computed gate: only fill the lock gap when Cocaine is active, lid-close sleep prevention is enabled, and display sleep prevention is off.

### 2026-04-26 12:12 — Spec approved

- Why: The written design matches the requested user-facing behavior and is ready for implementation planning.
- How: User approved `spec.md` and asked to continue to implementation planning.
- Decision: Proceed to a detailed plan that implements a macOS lock policy reader, delayed/cancellable lid-close lock scheduling, test coverage, and README updates.

### 2026-04-26 12:19 — Implementation plan generated

- Why: The approved behavior touches settings reads, asynchronous scheduling, app wiring, docs, and verification, so execution needs a stepwise TDD plan.
- How: Wrote `plan.md` with five tasks: policy reader, delayed responder scheduling, app wiring, README update, and final verification/task memory update.
- Decision: Use a focused `MacOSLockPolicyReader` plus `LidCloseLockScheduling` abstraction so policy reads and delayed lock timing can be tested without waiting real macOS timers.
