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

**Cursor:** Task 4 — final verification

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

### 2026-04-26 17:17 — Task 2 Developer ID signing requirements

- Summary: Updated the app and helper signing requirement strings from Apple Development certificate constraints to Developer ID Application constraints using Team ID A79T83GM42.
- Files changed: `Sources/CocaineCore/CocaineHelperProtocol.swift`, `Resources/Cocaine/Info.plist`, `Resources/CocaineHelper/Info.plist`, `Tests/CocaineCoreTests/CocaineHelperConstantsTests.swift`, and `docs/feat/20260426170356-release-signing-ci/context.md`.
- Commands run: `swift test --filter CocaineHelperConstantsTests` passed with 4 tests and 0 failures.
- Commit SHA: 0e2c7b0.

### 2026-04-26 17:23 — Task 3 release workflow

- Summary: Added the tag-triggered GitHub Actions release workflow and a Makefile `release-zip` target for signed app zip packaging.
- Files changed: `Makefile`, `.github/workflows/release.yml`, and `docs/feat/20260426170356-release-signing-ci/context.md`.
- Commands run: Task 3 content validation script passed for Makefile and workflow requirements.
- Commit SHA: d4ad6ba.

### 2026-04-26 17:28 — Task 3 release workflow quality fixes

- Summary: Accepted code quality review fixes for Task 3 by moving signing secrets to runner temp paths, renaming the keychain password path variable for clarity, deriving the exact Developer ID signing identity from the imported temporary keychain, removing the hard-coded signing identity, adding always-run signing material cleanup, and quoting the Makefile release zip paths.
- Files changed: `Makefile`, `.github/workflows/release.yml`, and `docs/feat/20260426170356-release-signing-ci/context.md`.
- Commands run: Task 3 quality validation script passed for temporary signing material paths, derived signing identity, cleanup step, quoted release zip paths, corrected Task 3 SHA, and a single follow-up LOG entry.
- New commit: `ci: harden release signing workflow`.

### 2026-04-26 17:33 — Task 4 final verification

- Summary: Completed final release signing CI verification without implementation changes.
- Commands run: `swift test` passed with 106 tests and 0 failures; `make app CONFIGURATION=release` passed locally using the installed Apple Development signing identity; the Markdown personal-use wording search returned no matches; the release workflow secret reference search found all six required secret names in `.github/workflows/release.yml` and `README.md`.
- Files changed: `docs/feat/20260426170356-release-signing-ci/context.md`.
- Unresolved follow-up: Full Developer ID notarization remains dependent on configured repository secrets and GitHub Actions execution on a `v*` tag.
