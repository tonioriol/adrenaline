---
title: "Rename app to Insomnia"
status: done
repos: [insomnia]
tags: [macos, spm]
created: 2026-04-26
---

# Rename app to Insomnia

## TASK

**Goal:** Plan a complete rename from the current app identity to Insomnia with no remaining references to the old name in source, resources, build outputs, tests, release workflow, or documentation.

**Done when:** A reviewed rename spec and implementation plan exist, covering source target names, bundle identifiers, helper identity, resources, docs, CI artifacts, and verification searches.

## SPEC

[spec.md](./spec.md) — Full no-traces rename to Insomnia with lowercase `com.tonioriol.insomnia` bundle identifiers.

## FILES

- Package.swift
- Makefile
- README.md
- NOTICE.md
- .github/workflows/release.yml
- Resources/
- Sources/
- Tests/
- docs/feat/

## PLAN

**Plan:** [plan.md](./plan.md)

**Cursor:** Complete — all rename tasks verified

**Status:** done

## LOG

### 2026-04-26 22:57 — Task started

- Why: Publishing under the current name creates avoidable reputation and distribution friction, and the user chose Insomnia as the replacement name.
- How: Initial scope is a full no-traces rename plan spanning product name, target names, bundle IDs, helper IDs, resources, docs, tests, and release automation.
- Decision: Pause GitHub remote/secrets/tag setup until the rename plan is approved and implemented.

### 2026-04-27 06:04 — Spec written

- Why: The rename affects bundle IDs, helper trust, target names, resources, CI, and docs, so it needs a complete design before edits.
- How: Captured visible name, Swift target names, lowercase public bundle identifiers under `com.tonioriol.insomnia`, no-migration stance, CI artifact names, and verification searches.
- Decision: Treat all tracked text as in scope for the no-traces rename; ignored build outputs and git internals are out of scope.

### 2026-04-27 06:05 — Implementation plan generated

- Why: The approved rename spec needs executable steps that preserve behavior while changing every public identity surface.
- How: Added `plan.md` with three tasks covering implementation identity, documentation/workspace text, and final verification/cleanup.
- Decision: Use deterministic rename scripts and verification searches with constructed legacy tokens so the final workspace can contain no literal legacy-name traces.


### 2026-04-27 06:10 — Task 1 implementation identity rename

- Files changed: `Package.swift`, `Makefile`, `.github/workflows/release.yml`, `Scripts/generate-app-icon.swift`, `Sources/Insomnia/`, `Sources/InsomniaCore/`, `Sources/InsomniaHelper/`, `Tests/InsomniaCoreTests/`, `Resources/Insomnia/`, `Resources/InsomniaHelper/`.
- Commands run: `git status --short --branch`; Task 1 `git mv` rename command block; Task 1 Python implementation rename mapping; Task 1 Python key identifier verification (`renamed identifiers verified`); `swift test --filter InsomniaHelperConstantsTests` (PASS: 4 tests, 0 failures); `git status --short`; pending commit command `git -c commit.gpgsign=false commit -m "refactor: rename app identity to insomnia"`.
- Commit SHA: pending at log write time; final commit SHA recorded in task response after commit creation.
- Decisions: Limited this pass to implementation identity surfaces only, leaving broader documentation/workspace text rename for Task 2 as requested; kept behavior unchanged while renaming visible name, Swift targets/modules, helper constants/protocol, bundle identifiers, helper label/Mach service, preference/log namespaces, app icon filename, and release artifact paths to Insomnia.

### 2026-04-27 06:27 — Task 2 documentation and workspace text rename

- Files changed: `README.md`, `NOTICE.md`, `docs/feat/`, `docs/scratch.md`, and `.vscode/launch.json` if present.
- Commands run: Task 2 Python documentation/workspace rename mapping; constructed-token content verification with `rg` (PASS: no matches, exit 1); constructed-token filename verification with `fd` and `rg` (PASS: no matches, exit 1); new docs verification with `rg -n 'Insomnia|build/Insomnia\.app|Insomnia is licensed|launch Insomnia at login' README.md NOTICE.md` (PASS: README title, app bundle path, license line, launch-at-login wording, and NOTICE attribution present).
- Decision: Rewrote docs and local workspace text, including the planning records, so tracked/local text contains only the Insomnia identity while ignored build artifacts and Git internals remain out of scope.

### 2026-04-27 06:32 — Task 2 quality follow-up

- Why: Review found duplicate VS Code launch entries, invalid launch pre-tasks without a tasks file, no-op spec path mappings after the no-traces rewrite, and contradictory verification wording.
- How: Kept one launch configuration for each Insomnia app/helper debug/release target, removed launch pre-tasks, rewrote the spec scope to describe legacy-name intent without literal legacy tokens, and clarified that constructed legacy-token searches should be empty while Insomnia searches should show expected renamed references.
- Decision: Accepted all Task 2 quality findings as documentation/workspace correctness fixes; no behavior or build-system changes were needed.

### 2026-04-27 06:38 — Task 3 final verification and cleanup

- Files changed: `docs/feat/20260426225736-rename-insomnia/context.md` and `docs/feat/20260426225736-rename-insomnia/plan.md` only.
- Commands run: `make clean` (PASS: removed generated `.build` and `build` artifacts); `swift test` (PASS: 106 tests, 0 failures); `make app CONFIGURATION=release` (PASS: built and signed `build/Insomnia.app` with local Apple Development identity); `make release-zip CONFIGURATION=release` (PASS: created `build/Insomnia.zip`); PlistBuddy bundle identifier checks (PASS: `com.tonioriol.insomnia`, `com.tonioriol.insomnia.helper`, `com.tonioriol.insomnia.helper`); constructed-token content verification with `rg` (PASS: no matches, exit 1); constructed-token filename verification with `fd` and `rg` (PASS: no matches, exit 1); Insomnia reference sample with `rg` (PASS: renamed package, build, docs, bundle ID, helper ID, and test references present).
- Local-only leftovers: generated `.build/`, `build/Insomnia.app`, and `build/Insomnia.zip` exist after the release verification by design and remain ignored build artifacts; no remote state was mutated.
- Decision: Marked Task 2 and Task 3 complete and set the plan cursor/status to terminal because all required verification commands passed.
