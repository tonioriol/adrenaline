---
title: "Use capsule as app icon"
status: active
repos: [cocaine]
tags: [macos, spm]
created: 2026-04-26
---

# Use capsule as app icon

## TASK

**Goal:** Make the existing capsule menu bar icon also serve as the macOS app bundle icon.

**Done when:** The app bundle declares and packages an app icon derived from the capsule status-item design, and the build path verifies successfully.

## SPEC

<!-- Link to sibling spec.md after design approval. -->

## FILES

- `Sources/Cocaine/MenuBarController.swift` — current capsule status-item icon drawing
- `Resources/Cocaine/Info.plist` — app bundle metadata
- `Makefile` — app bundle construction and signing

## PLAN

**Plan:** pending

**Cursor:** Brainstorming — exploring existing icon and app bundle packaging

**Status:** in_progress

## LOG

### 2026-04-26 16:30 — Started app icon design task

- Why: The menu bar already uses a custom capsule/pill metaphor, but the app bundle lacks a matching macOS app icon.
- How: Created this task ledger and identified the likely touch points: status-item icon drawing, app bundle metadata, and bundle packaging.
