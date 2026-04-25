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

_Pending — to be written after design approval._

## FILES

- `docs/scratch.md` — original musing prompting the task
- `docs/feat/20260424192541-merge-fermatta-caffeine/spec.md` — current one-toggle behavior reference
- `docs/feat/20260425200131-lid-event-sounds/spec.md` — current lid-event sound behavior reference
- `Sources/CocaineCore/AppCoordinator.swift` — current activation/rollback orchestration
- `Sources/CocaineCore/AwakeController.swift` — current ordinary IOKit assertion controller
- `Sources/CocaineCore/LidCloseController.swift` — current lid-close prevention boundary
- `Sources/Cocaine/MenuBarController.swift` — current menu bar UI and right-click menu

## PLAN

_Pending — to be written after spec approval._

## LOG

### 2026-04-25 23:29 — Task memory created

- Why: User raised settings ideas in `docs/scratch.md` that change behavior and need a design before implementation.
- How: Created this task ledger after confirming no existing task covers configurable lid-close behavior; the prior tasks covered initial keep-awake and lid event sounds only.
