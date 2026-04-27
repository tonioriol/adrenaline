---
title: "Respect macOS lock policy for lid-close timing"
status: done
repos: [insomnia]
tags: [macos, power, security]
related: [20260425232900-lid-behavior-settings, 20260426083000-lid-behavior-refinements]
created: 2026-04-26
---

# Respect macOS lock policy for lid-close timing

## TASK

**Goal:** Make Insomnia's lid-close lock behavior follow the user's macOS lock policy and display-off timer instead of always locking immediately when lid-close sleep prevention keeps the system awake.

The current computed lock path fills the gap where `SleepDisabled = true` prevents macOS from reaching its native sleep/screensaver lock trigger. The requested refinement is to preserve that gap-fill behavior only when macOS itself would require a password, and to delay the gap-fill lock according to the relevant macOS display-off timing rather than firing instantly on lid close.

**Done when:** Insomnia does not force-lock on lid close when macOS Require Password is disabled, and otherwise schedules lid-close locking based on the effective macOS display-off timer for the current power source while preserving existing sleep-prevention and menu behavior.

## SPEC

[spec.md](./spec.md) — design for matching macOS lid-close lock policy by delaying lock until display-off timer plus password delay, and skipping locks when Require Password is disabled.

## FILES

- Sources/InsomniaCore/LidCloseLockResponder.swift — delayed computed lid-close lock behavior
- Sources/InsomniaCore/LidCloseLockScheduler.swift — cancellable delayed lock scheduler abstraction
- Sources/InsomniaCore/MacOSLockPolicyReader.swift — macOS Require Password/display timer policy reader
- Sources/InsomniaCore/ScreenLocker.swift — lock implementation used by lid-close responder
- Sources/InsomniaCore/PreferencesStore.swift — app preference state that currently controls display and lid behavior
- Sources/InsomniaHelper/ApplePowerSettings.swift — existing helper-side macOS power settings access
- Sources/Insomnia/AppDelegate.swift — wires lid event sound and lock responders against one lid monitor
- Sources/Insomnia/MenuBarController.swift — current menu exposes display/lid/sound/login controls but no lock row
- Sources/InsomniaCore/PreferenceMenuRows.swift — current preference row model with no standalone lock row
- Tests/InsomniaCoreTests/LidCloseLockResponderTests.swift — lock behavior regression tests
- Tests/InsomniaCoreTests/MacOSLockPolicyReaderTests.swift — policy reader regression tests
- README.md — user-facing behavior table updated for macOS-matched lid-close locking

## PLAN

**Plan:** [plan.md](./plan.md)

**Cursor:** Complete — implementation and verification finished.

**Status:** done

## LOG

### 2026-04-26 11:50 — Task memory created

- Why: The requested behavior changes the security semantics of lid-close locking and depends on macOS settings, so it needs an explicit design record before implementation.
- How: Created this ledger and linked the prior lid behavior tasks that introduced preferences, display-sleep handling, and computed lid-close locking.
- Decision: Treat the change as a refinement of computed lid-close locking rather than a new visible menu preference unless design exploration shows a user-facing control is needed.

### 2026-04-26 11:53 — Current behavior and macOS setting sources identified

- Why: The design needs to preserve the existing computed lock matrix while replacing the immediate lock trigger with macOS-policy-aware timing.
- How: Confirmed `LidCloseLockResponder` currently locks immediately only when Insomnia is active, lid-close prevention is enabled, and display-sleep prevention is off. `ScreenLocker` uses `SACLockScreenImmediate` with command fallbacks. The menu has no standalone lock row. On this Mac, `pmset -g custom` reports `displaysleep = 1` on battery and `displaysleep = 5` on AC, and `defaults read com.apple.screensaver` reports `askForPassword = 1`, `askForPasswordDelay = 0`. The backing power-management plist exposes `Display Sleep Timer` entries under `Battery Power` and `AC Power`.
- Decision: Model the new design around a focused macOS policy reader that supplies lock-enabled state plus current display-off delay, and keep the responder as the place that schedules/cancels the best-effort lock.

### 2026-04-26 12:01 — Lock timing clarified as full macOS lock timing

- Why: A display-off-only delay would still be surprising when the macOS Require Password setting uses a non-immediate delay.
- How: User selected matching macOS as the guiding rule: lock after display-off timer plus Require Password delay, and do not lock at all when Require Password is Never.
- Decision: The spec should define Insomnia's lid-close lock as a best-effort emulation of when macOS would actually require a password, not merely when the display would turn off.

### 2026-04-26 12:05 — Spec written for macOS-matching lid-close lock timing

- Why: User approved the plain-English design: check macOS settings on lid close, skip locking when Require Password is Never, otherwise delay by current display-off timer plus password delay, and cancel on lid reopen.
- How: Wrote `spec.md` covering user-facing behavior, policy reading, delayed responder scheduling, cancellation/recheck rules, tests, docs, risks, and rejected alternatives.
- Decision: Keep the feature invisible in the menu and preserve the current computed gate: only fill the lock gap when Insomnia is active, lid-close sleep prevention is enabled, and display sleep prevention is off.

### 2026-04-26 12:12 — Spec approved

- Why: The written design matches the requested user-facing behavior and is ready for implementation planning.
- How: User approved `spec.md` and asked to continue to implementation planning.
- Decision: Proceed to a detailed plan that implements a macOS lock policy reader, delayed/cancellable lid-close lock scheduling, test coverage, and README updates.

### 2026-04-26 12:19 — Implementation plan generated

- Why: The approved behavior touches settings reads, asynchronous scheduling, app wiring, docs, and verification, so execution needs a stepwise TDD plan.
- How: Wrote `plan.md` with five tasks: policy reader, delayed responder scheduling, app wiring, README update, and final verification/task memory update.
- Decision: Use a focused `MacOSLockPolicyReader` plus `LidCloseLockScheduling` abstraction so policy reads and delayed lock timing can be tested without waiting real macOS timers.

### 2026-04-26 14:22 — Task 1 macOS lock policy reader

- Why: Later lid-close scheduling needs a testable snapshot of whether macOS requires a password and when macOS would lock for the active power source.
- How: Added `Sources/InsomniaCore/MacOSLockPolicyReader.swift` and `Tests/InsomniaCoreTests/MacOSLockPolicyReaderTests.swift`; confirmed RED with `swift test --filter MacOSLockPolicyReaderTests 2>&1 | tail -40` failing because `MacOSLockPolicyReader`, `MacOSPowerSource`, and `MacOSLockPolicyReaderError` were missing; confirmed GREEN with the same command passing 10 tests, 0 failures; committed `26bb89d`.
- Decision: Treat unknown power source as battery-first fallback to match the approved conservative behavior and clamp negative display/password delays to zero at the policy boundary.

### 2026-04-26 14:31 — Task 2 delayed lid-close lock scheduling

- Why: The responder needed to preserve the computed lid-close lock gate while matching macOS timing instead of locking immediately.
- How: Replaced `Tests/InsomniaCoreTests/LidCloseLockResponderTests.swift` with delayed scheduling/cancellation/recheck coverage; confirmed RED with `swift test --filter LidCloseLockResponderTests 2>&1 | tail -60` failing on missing scheduler and initializer labels; added `Sources/InsomniaCore/LidCloseLockScheduler.swift`; refactored `Sources/InsomniaCore/LidCloseLockResponder.swift` to read `MacOSLockPolicyReading`, schedule cancellable delayed locks, cancel on lid open, and recheck state/preferences/lid before locking; confirmed GREEN with `swift test --filter LidCloseLockResponderTests 2>&1 | tail -60` passing 12 tests, 0 failures; committed `bcc16c8`.
- Decision: Kept a compatibility initializer that creates the default policy reader so existing app wiring continues to build until Task 3 explicitly injects the reader. Review fix: removed that implicit policy-wiring initializer so Task 3 owns the explicit `MacOSLockPolicyReader` integration point; committed `a82c2ce`.
- Review continuation: Accepted Task 2 quality feedback by replacing asynchronous deinit cancellation with synchronous main-actor-isolated cancellation and adding focused current-lid-state recheck coverage that does not use the lid-open callback cancellation path. Evidence: `swift test --filter LidCloseLockResponderTests 2>&1 | tail -80` still stops at the expected Task 3 `AppDelegate.swift` missing `policyReader:` wiring error with no new Task 2 errors; `swift build --target InsomniaCoreTests 2>&1 | tail -80` compiled the focused test target; `swift test --skip-build --filter LidCloseLockResponderTests 2>&1 | tail -80` passed 12 tests, 0 failures. Commit: `c56076a`.

### 2026-04-26 14:50 — Task 3 app policy reader wiring

- Why: Production app wiring still used the old `LidCloseLockResponder` initializer, so the app target could not compile after the responder was changed to require an explicit macOS lock policy reader.
- How: Updated `Sources/Insomnia/AppDelegate.swift` to construct `MacOSLockPolicyReader()` next to `LoginFrameworkScreenLocker()` and pass it as `policyReader:` while preserving sound-controller-before-responder construction order. Evidence: initial `swift build 2>&1 | tail -40` failed with missing `policyReader`; after wiring, `swift build 2>&1 | tail -40` passed and `swift test 2>&1 | tail -40` passed 106 XCTest tests, 0 failures. Commit: `2a518e1`.
- Decision: Kept the existing lid event sound controller construction before `LidCloseLockResponder` so the responder continues to wrap and forward the existing lid-state callback.

### 2026-04-26 14:58 — Task 4 README lock policy docs

- Why: The README still described the removed standalone lock row and older immediate/separate lid-close lock behavior, but the implemented behavior now mirrors macOS Require Password and display-off timing.
- How: Updated README.md behavior preferences and lid-close bullets; ran `rg -n "Lock screen on lid close|separate lid-close lock action|lock action fires" README.md`, which returned no matches; committed README update as `90e5351`.
- Decision: Removed the lock preference row entirely and documented the computed behavior matrix instead, because Insomnia has no user-facing lock setting and only fills the macOS lock gap when display sleep is allowed.

### 2026-04-26 15:04 — macOS-matched lid-close lock timing implemented

- Why: Insomnia should not create a separate lid-close security policy; it should respect macOS Require Password and display-off timing.
- How: Added `MacOSLockPolicyReader`, delayed/cancellable `LidCloseLockResponder` scheduling, explicit app wiring, and README docs. Verification: `make test 2>&1 | tail -40` passed with 106 XCTest tests and 0 failures; `make app 2>&1 | tail -40` rebuilt and signed `build/Insomnia.app`; `rg -n "locks the screen when the lid closes|lock as soon as the lid closes|immediate.*lid" README.md Sources Tests` returned no matches. Implementation commits: `26bb89d`, `bcc16c8`, `a82c2ce`, `c56076a`, `2a518e1`, `90e5351`. Final verification record committed as `2119582`.
- Decision: Lock timing is read once at lid close and rechecked for active/lid/preference gates before firing; power-source changes while already closed remain a future refinement. Manual physical-lid verification is still pending.

### 2026-04-26 15:03 — Final implementation wrap-up

- Why: Insomnia should not create a separate lid-close security policy; it should respect macOS Require Password and display-off timing.
- How: Added `MacOSLockPolicyReader`, delayed/cancellable `LidCloseLockResponder` scheduling, production app wiring, and README docs across commits `26bb89d`, `bcc16c8`, `a82c2ce`, `c56076a`, `2a518e1`, and `90e5351`. Verification: `make test 2>&1 | tail -40` passed 106 XCTest tests with 0 failures; `make app 2>&1 | tail -40` rebuilt `build/Insomnia.app` and signed the app/helper; `rg -n "locks the screen when the lid closes|lock as soon as the lid closes|immediate.*lid" README.md Sources Tests` returned no matches.
- Decision: Lock timing is read once at lid close and rechecked for active/lid/preference gates before firing; power-source changes while already closed are left as a future refinement.

### 2026-04-26 16:19 — Local merge option resolved on main

- Why: The chosen completion path was to merge the work locally into `main`.
- How: Verified the branch was already [`main`](.git/HEAD) with the implementation commits present directly in local history, so no extra checkout or merge step was required. Re-ran `make test 2>&1 | tail -40` to confirm the current local `main` still passed with 106 tests and 0 failures. No worktree cleanup was needed because the workspace is the primary repository path.
- Decision: Treat the feature as already merged locally; leave unrelated untracked workspace files (`.gitkeep`, `.vscode/`, `docs/scratch.md`) untouched.
