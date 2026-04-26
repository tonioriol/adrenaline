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

**Cursor:** Task 2 — update Developer ID signing requirements

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

### 2026-04-26 17:09 — Task 1 implemented

- Summary: Added the AGPL-3.0 license notice, removed personal-only wording, and documented release secrets plus license details in README.
- Files changed: `LICENSE`, `README.md`, `NOTICE.md`, `docs/feat/20260424192541-merge-fermatta-caffeine/spec.md`, `docs/feat/20260424192541-merge-fermatta-caffeine/context.md`, `docs/feat/20260424192541-merge-fermatta-caffeine/plan.md`, `docs/feat/20260425200131-lid-event-sounds/plan.md`, `docs/feat/20260425232900-lid-behavior-settings/plan.md`, `docs/feat/20260426083000-lid-behavior-refinements/plan.md`, `docs/feat/20260426170356-release-signing-ci/plan.md`, and `docs/feat/20260426170356-release-signing-ci/context.md`.
- Commands run: Python file update script; the required Markdown wording cleanup search first found additional out-of-scope historical matches, then passed with no matches after approved expanded cleanup.
- Commit SHA: a3dd097.
- Decision: Expanded cleanup beyond the original Task 1 file list after approval so the exact verification command returns no matches across all Markdown files.

### 2026-04-26 17:12 — Task 1 wording follow-up

- Why: Spec review found three archived plan snippets still used personal keep-awake wording after the initial Task 1 cleanup.
- How: Updated the remaining `.credits` strings in the lid behavior refinement, merge, and lid behavior settings plans, then reran the required Markdown wording search with no matches.
- Decision: Keep the attribution text intact while removing only the personal-use framing.
