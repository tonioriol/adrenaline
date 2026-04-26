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

[spec.md](./spec.md) — approved design for packaging a generated capsule-based `.icns` as the macOS app icon.

## FILES

- `Sources/Cocaine/MenuBarController.swift` — current capsule status-item icon drawing
- `Resources/Cocaine/Info.plist` — app bundle metadata
- `Makefile` — app bundle construction and signing
- `Scripts/generate-app-icon.swift` — planned reproducible app icon generator
- `Resources/Cocaine/Cocaine.icns` — planned generated app bundle icon

## PLAN

**Plan:** [plan.md](./plan.md)

**Cursor:** Task 1 — add reproducible capsule icon generator

**Status:** in_progress

## LOG

### 2026-04-26 16:30 — Started app icon design task

- Why: The menu bar already uses a custom capsule/pill metaphor, but the app bundle lacks a matching macOS app icon.
- How: Created this task ledger and identified the likely touch points: status-item icon drawing, app bundle metadata, and bundle packaging.

### 2026-04-26 16:38 — Spec approved

- Why: The implementation needs a narrow design before changing bundle resources and packaging metadata.
- How: Compared `.icns`, asset catalog, and runtime-only app icon approaches; selected the `.icns` bundle path because it is the simplest Finder/Launch Services-compatible fit for the current SwiftPM/Makefile app bundle.
- Decision: Generate a proper macOS-style icon from the existing diagonal capsule motif, declare it in `Info.plist`, and copy it into `Contents/Resources` during the `Makefile` app build.

### 2026-04-26 16:39 — Implementation plan generated

- Why: The approved design needs a concrete sequence that keeps asset generation reproducible and bundle wiring verifiable.
- How: Wrote `plan.md` with 3 tasks: add a Swift/AppKit `.icns` generator and generated asset, wire `Info.plist`/`Makefile`, then verify tests and bundle output.

### 2026-04-26 16:41 — Task 1 generator and icon added

- Why: Task 1 needed a reproducible source for the capsule-based app icon asset before bundle metadata and packaging are wired.
- How: Added `Scripts/generate-app-icon.swift`, generated `Resources/Cocaine/Cocaine.icns`, verified it with `sips -g pixelWidth -g pixelHeight Resources/Cocaine/Cocaine.icns` reporting 1024 × 1024, and committed the generator plus generated icon as `de7cd0f`.
- Follow-up: Task 2 should wire `CFBundleIconFile` and copy `Cocaine.icns` into the app bundle resources.
