---
title: "Add lid-close and lid-open sounds"
status: active
repos: [cocaine]
tags: [macos, sound]
created: 2026-04-25
---

# Add lid-close and lid-open sounds

## TASK

**Goal:** Design and implement audible feedback for lid-close and lid-open events while Cocaine is preventing sleep, so the user can tell the app was left enabled and the Mac remained awake.

The approved design uses passive app-side lid observation with built-in macOS sounds: Hero when the lid closes, Basso when the lid opens. Sounds are auxiliary feedback and must not change sleep-prevention activation, rollback, or cleanup behavior.

**Done when:** The app passively monitors lid events while active, plays Hero on close and Basso on open, suppresses duplicate state notifications, remains silent while inactive, and passes automated verification plus manual MacBook validation.

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

**Cursor:** Task 1 — Lid Event Sound Policy

**Status:** in_progress

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
