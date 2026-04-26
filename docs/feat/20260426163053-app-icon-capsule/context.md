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
- `Scripts/generate-app-icon.swift` — reproducible app icon generator
- `Resources/Cocaine/Cocaine.icns` — generated app bundle icon

## PLAN

**Plan:** [plan.md](./plan.md)

**Cursor:** all tasks complete

**Status:** complete

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

### 2026-04-26 16:52 — Task 1 icon generation reproducibility fix

- Why: Review found the generator used point-sized `NSImage` rendering through AppKit, which could serialize iconset PNGs at host-dependent Retina scale instead of the requested pixel dimensions.
- How: Updated `Scripts/generate-app-icon.swift` to render each iconset entry into an explicit `NSBitmapImageRep` sized in pixels, added per-PNG bitmap dimension verification before invoking `iconutil`, regenerated `Resources/Cocaine/Cocaine.icns`, and verified extracted iconset entries from 16 × 16 through 1024 × 1024 pixels.
- Follow-up: Task 2 should wire `CFBundleIconFile` and copy `Cocaine.icns` into the app bundle resources.

### 2026-04-26 17:09 — App icon implementation complete

- Why: All planned work for using the capsule motif as the macOS app icon has passed implementation, specification review, quality review, and bundle verification.
- How: Completed generator, packaging, and verification tasks across commits `de7cd0f`, `4b04c2d`, `91de93b`, `98aae13`, `17f14bc`, and `c0f52ba`; verified `swift test` passed with 106 XCTest tests, `make app` built and signed `build/Cocaine.app`, `build/Cocaine.app/Contents/Resources/Cocaine.icns` exists, and the built `Info.plist` reports `CFBundleIconFile` as `Cocaine`.

### 2026-04-26 17:02 — Task 2 bundle icon metadata and packaging

- Why: The generated capsule app icon needed to be declared in the app bundle metadata and copied into the manually packaged app bundle resources.
- How: Added `CFBundleIconFile` to `Resources/Cocaine/Info.plist`, added `RESOURCES_DIR` plus `generate-app-icon` to `Makefile`, and updated the `app` recipe to create `Contents/Resources` and copy `Resources/Cocaine/Cocaine.icns` before signing. Verification: `make generate-app-icon` passed and refreshed the icon asset. Commit: `17f14bc`.
- Follow-up: Task 3 should verify the built bundle output contains `Contents/Resources/Cocaine.icns` and the copied plist reports `CFBundleIconFile` as `Cocaine`.


### 2026-04-26 17:06 — Task 3 bundle output verified

- Why: The completed icon metadata and packaging needed final verification through the app bundle build path.
- How: Ran `swift test` (106 XCTest tests passed, plus Swift Testing reported 0 tests passed), `make app` (bundle built and signed), verified `build/Cocaine.app/Contents/Resources/Cocaine.icns` exists with `icon copied`, and verified the built `Info.plist` reports `CFBundleIconFile` as `Cocaine`.
- Follow-up: No implementation fixes were required. `git status --short` showed only pre-existing untracked workspace files: `.gitkeep`, `.vscode/`, and `docs/scratch.md`.
