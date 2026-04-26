---
title: "Release signing CI"
status: active
repos: [cocaine]
tags: [ci-cd, security, spm]
created: 2026-04-26
---

# Release signing CI

## TASK

**Goal:** Remove personal-use wording and add a minimal CI release path that builds, signs, notarizes, and packages the macOS app with the user's Apple Developer ID.

**Done when:** Documentation no longer frames the app as personal-only, and CI can produce a signed and notarized release artifact from configured Apple signing secrets.

## SPEC

[spec.md](./spec.md) — Minimal GitHub Actions release workflow for signed and notarized app zips.

## FILES

- NOTICE.md
- README.md
- LICENSE
- Makefile
- Resources/Cocaine/Info.plist
- Resources/CocaineHelper/Info.plist
- Sources/CocaineCore/CocaineHelperProtocol.swift
- Tests/CocaineCoreTests/CocaineHelperConstantsTests.swift
- .github/workflows/release.yml

## PLAN

**Plan:** [plan.md](./plan.md)

**Cursor:** Task 1 — add AGPL license and clean wording

**Status:** ready

## LOG

### 2026-04-26 17:03 — Task started

- Why: The app is moving from local/personal framing toward public release artifacts.
- How: Initial scope is limited to wording cleanup plus a minimal CI workflow for Developer ID signing and Apple notarization.
- Decision: Keep the plan intentionally small and focused on release automation, not broader packaging polish.

### 2026-04-26 17:05 — Spec approved and written

- Why: The release path needs a precise but small design before changing signing-sensitive files.
- How: Captured the approved tag-triggered GitHub Actions workflow, Developer ID signing requirements, documentation cleanup scope, and non-goals.
- Decision: Use a zipped app artifact rather than adding DMG generation or a separate release script.

### 2026-04-26 17:06 — License scope added

- Why: The project should include an explicit open-source license before public release.
- How: Added AGPL licensing to the approved release CI spec as a minimal repository-level `LICENSE` plus README reference.
- Decision: Use AGPL-3.0 as requested, without adding extra licensing automation.

### 2026-04-26 17:06 — Implementation plan generated

- Why: The approved spec needs concrete implementation steps that keep the work small and verifiable.
- How: Added `plan.md` with four tasks covering license and wording cleanup, Developer ID signing requirements, GitHub Actions release automation, and verification.
- Decision: Keep release packaging as zip-only and rely on the existing Makefile app bundle flow.
