---
title: "Rename app to Insomnia"
status: active
repos: [cocaine]
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

**Cursor:** Task 1 — rename implementation identity

**Status:** ready

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
