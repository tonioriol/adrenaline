---
title: "Add lid-close and lid-open sounds"
status: done
repos: [cocaine]
tags: [macos, sound]
created: 2026-04-25
---

# Add lid-close and lid-open sounds

## TASK

**Goal:** Design and implement audible feedback for lid-close and lid-open events while Cocaine is preventing sleep, so the user can tell the app was left enabled and the Mac remained awake.

The approved design uses passive app-side lid observation with built-in macOS sounds: Hero when the lid closes, Basso when the lid opens. Sounds are auxiliary feedback and must not change sleep-prevention activation, rollback, or cleanup behavior.

**Done when:** The app passively monitors lid events while active, plays Hero on close and Basso on open, suppresses duplicate state notifications, remains silent while inactive, and passes automated verification. Manual MacBook validation remains the only follow-up.

## SPEC

[spec.md](./spec.md) — passive app-side lid observer with Hero on close and Basso on open, pending written review.

## FILES

- `docs/feat/20260425200131-lid-event-sounds/context.md` — task ledger
- `Sources/CocaineCore/AppCoordinator.swift` — current one-toggle activation, rollback, and shutdown coordination
- `Sources/CocaineCore/LidCloseController.swift` — current lid-close prevention boundary
- `Sources/Cocaine/AppDelegate.swift` — app lifecycle wiring for controllers
- `Sources/Cocaine/MenuBarController.swift` — current menu bar UI and user actions
- `Sources/Cocaine/SystemSoundPlayer.swift` — planned AppKit built-in sound wrapper
- `Sources/CocaineCore/LidEventSoundController.swift` — planned lid sound policy coordinator
- `Sources/CocaineCore/LidStateMonitor.swift` — planned passive IOKit lid state monitor
- `Package.swift` — SwiftPM targets and framework links
- `Makefile` — app bundle construction and signing
- `README.md` — user-facing behavior and safety notes
- `Tests/CocaineCoreTests/LidEventSoundControllerTests.swift` — planned policy tests
- `Tests/CocaineCoreTests/LidStateMonitorTests.swift` — planned monitor decoding tests

## PLAN

**Plan:** [plan.md](./plan.md)

**Cursor:** All planned tasks complete; manual MacBook validation pending

**Status:** complete_with_manual_followup

## LOG

### 2026-04-25 22:01 — Task memory created

- Why: The requested sound feature changes app behavior and needs a design before implementation.
- How: Created this task ledger after checking existing task memory; the previous task covers the initial keep-awake app, not lid event sounds.

### 2026-04-25 22:02 — Existing architecture reviewed

- Why: The sound feature should fit the current small SwiftPM/AppKit architecture without disturbing helper-owned lid-close prevention.
- How: Reviewed the coordinator, lid-close controller, app delegate, menu bar controller, package, build rules, and README. The app currently has a testable `CocaineCore` library, an AppKit menu bar executable, and a privileged helper; there is no lid event observer or audio playback component yet.
- Decision: Treat lid event detection and sound playback as new app-side components, while keeping the privileged helper focused on enabling/disabling lid-close sleep prevention.

### 2026-04-25 22:29 — Built-in sound choices selected

- Why: The feature should provide distinct audible confirmation for close and open without bundling custom assets.
- How: Auditioned installed macOS system sounds from `/System/Library/Sounds` with `afplay`; the user selected Hero for lid close and Basso for lid open.
- Decision: Use built-in macOS sounds initially: close = Hero, open = Basso.

### 2026-04-25 22:37 — Spec written

- Why: The app-side passive observer design was approved section by section and needed to be captured before implementation planning.
- How: Added `spec.md` covering goals, behavior, architecture, component responsibilities, data flow, error handling, testing, risks, and rejected alternatives.
- Decision: Keep sounds auxiliary: monitoring or playback failures must not affect sleep-prevention activation or helper cleanup.

### 2026-04-25 22:39 — Spec approved

- Why: The user approved the written design and asked to proceed without further approval gates.
- How: Marked the task framing and cursor for implementation planning based on the approved spec.
- Decision: Proceed to the implementation plan for the passive app-side observer design.

### 2026-04-25 22:47 — Implementation plan generated

- Why: The approved spec requires a task-by-task implementation path with tests, app wiring, documentation, and verification.
- How: Added `plan.md` with five tasks: sound policy, passive IOKit monitor, AppKit sound playback/wiring, README update, and final verification/manual validation notes.
- Decision: Execute with task-level TDD and keep the privileged helper unchanged.

### 2026-04-25 22:50 — Task 1 lid event sound policy

- Why: Add the testable core policy that starts passive lid monitoring only when Cocaine is active and maps lid-close/open events to the selected built-in sounds without changing activation state.
- How: Added `Sources/CocaineCore/LidEventSoundController.swift` with `LidState`, `LidStateMonitoring`, `LidSoundPlaying`, active-state monitoring lifecycle, duplicate suppression, and silent monitor-start failure handling; added `Tests/CocaineCoreTests/LidEventSoundControllerTests.swift` covering activation start, close/open sounds, inactive silence, duplicate suppression, deactivation reset, and start failure state preservation. Evidence: `swift test --filter LidEventSoundControllerTests` failed before implementation due to missing policy symbols, then `swift test --filter LidEventSoundControllerTests && swift test` passed with 7 filtered tests and 40 total XCTest tests. Commit: `f9753e7`.
- Decision: Main-actor-isolated the monitor and sound-player protocols because the controller, app state observation, and planned AppKit sound playback are main-actor UI-adjacent concerns and this avoids Swift concurrency conformance warnings.

### 2026-04-25 22:56 — Task 2 passive lid state monitor

- Why: Add the concrete passive app-side IOKit observer that converts raw clamshell power-management notifications into normalized open/closed lid states for the existing sound policy.
- How: Added `Sources/CocaineCore/LidStateMonitor.swift` with a `@MainActor` `LidStateMonitoring` implementation, IOPM root-domain interest notification registration, explicit start/stop resource management, IOKit error reporting, and deterministic clamshell argument decoding; added `Tests/CocaineCoreTests/LidStateMonitorTests.swift` covering state-bit decoding, sleep-bit ignoring, and the Swift-defined clamshell message constant. Evidence: `swift test --filter LidStateMonitorTests` failed before implementation because `LidStateMonitor` was missing, then `swift test --filter LidStateMonitorTests`, `swift test --filter 'Lid(EventSoundController|StateMonitor)Tests'`, and `swift test` passed with 4 monitor tests, 11 lid event tests, and 44 total XCTest tests. Commit: `41e928a`.
- Decision: Omitted `deinit` cleanup to avoid calling actor-isolated `stop()` from a nonisolated deinitializer; lifecycle cleanup remains explicit through `stop()` as planned.

### 2026-04-25 23:01 — Task 2 quality fix

- Why: Code quality review found the monitor should defensively unregister external IOKit resources if it is deallocated while monitoring is still active.
- How: Added deinitialization cleanup in `Sources/CocaineCore/LidStateMonitor.swift` for the run-loop source, notifier, root domain object, and notification port. Verified with `swift test --filter LidStateMonitorTests && swift test`. Commit: `3a87f11`.
- Decision: Kept `stop()` as the normal lifecycle path and added `deinit` as a defensive resource-owner safety net.

### 2026-04-25 23:04 — Task 3 app sound wiring

- Why: The app needed to retain the lid event sound policy for the application lifetime and provide the AppKit playback boundary for the selected built-in macOS sounds.
- How: Updated `Sources/Cocaine/AppDelegate.swift` to instantiate `LidStateMonitor`, `SystemSoundPlayer`, and retain `LidEventSoundController`; added `Sources/Cocaine/SystemSoundPlayer.swift` as the `NSSound` wrapper. Evidence: `swift build` failed before the wrapper because `SystemSoundPlayer` was missing, then `swift build`, `swift test`, and `make app` passed; `build/Cocaine.app` was created. Commit: `fb84e13`.

### 2026-04-25 23:09 — Task 4 user-facing documentation

- Why: The README needed to describe the new lid-close and lid-open sound behavior for users after the feature implementation.
- How: Updated README.md behavior text to mention silent off-state behavior plus Hero-on-close and Basso-on-open while on; verified with `git diff -- README.md`; committed the documentation update as `9f917bb`.

### 2026-04-25 23:12 — Lid event sounds implemented

- Why: The approved feature needed audible close/open feedback while lid-close prevention is active.
- How: Added testable lid sound policy, passive IOKit lid state monitoring, AppKit built-in sound playback, app lifecycle wiring, and README behavior docs. Verified `make clean && make test && make app` passed with 44 XCTest tests and signed app bundle creation. Confirmed built-in sound files resolve with `Hero: ok` for `/System/Library/Sounds/Hero.aiff` and `Basso: ok` for `/System/Library/Sounds/Basso.aiff`; manual MacBook validation remains pending.
- Decision: Kept sound monitoring app-side and auxiliary; helper behavior and sleep-prevention rollback paths remain unchanged.

### 2026-04-25 23:16 — Planned implementation complete

- Why: All planned design, implementation, review, documentation, and automated verification tasks are complete.
- How: Completed Tasks 1–5 across commits `f9753e7`, `41e928a`, `3a87f11`, `fb84e13`, `9f917bb`, and `f3d2590`, with task-level spec and quality reviews passing. Updated `plan.md` checkboxes and set this ledger to done with the manual MacBook validation follow-up recorded explicitly.
- Decision: Treat the implementation as complete for code and automated verification; keep hardware lid-close/open validation as a manual follow-up rather than overclaiming it.
