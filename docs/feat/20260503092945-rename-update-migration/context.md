---
title: "Deliver Adrenaline rename via Sparkle update"
status: active
repos: [adrenaline]
tags: [migration]
created: 2026-05-03
---

# Deliver Adrenaline rename via Sparkle update

## TASK

**Goal:** Existing Sparkle-enabled Insomnia installs must discover and install Adrenaline through the update channel, without requiring a manual reinstall.

The repo, release workflow, cask, bundle identifiers, and local folder were already renamed to Adrenaline. That completed the product rename, but it also moved the current app to the Adrenaline update feed while older installed Insomnia builds still point at the legacy Insomnia appcast URL. The result is a broken migration path for existing users unless we explicitly design a bridge release/update strategy.

**Done when:** A user already running a Sparkle-enabled Insomnia build can use the updater and end up on Adrenaline through an intentional migration path, with the release/appcast mechanics clearly defined.

## SPEC

[spec.md](./spec.md) — Temporary legacy Insomnia feed, 3-month sunset window, and one package-based migration into Adrenaline.

## FILES

- Resources/Adrenaline/Info.plist
- Sources/Adrenaline/SparkleUpdaterController.swift
- .github/workflows/release.yml
- Makefile
- Scripts/migration/postinstall
- Scripts/migration/build-migration-pkg.sh
- gh-pages: adrenaline appcast.xml
- gh-pages: insomnia appcast.xml (new legacy repo)

## PLAN

**Plan:** [plan.md](./plan.md)

**Cursor:** Task 1 — Fix the adrenaline gh-pages appcast metadata

**Status:** in_progress

## LOG

### 2026-05-03 09:29 — Task opened for updater migration design

- Why: The rename from Insomnia to Adrenaline was shipped as a product/repository rename, but existing installed Insomnia builds still check the old Sparkle feed and therefore cannot discover the new Adrenaline line automatically.
- How: Created a dedicated task ledger to design the Sparkle/appcast/release migration path before making more updater changes.
- Decision: Treat this as a migration design problem, not a cosmetic rename follow-up.

### 2026-05-03 12:16 — Spec approved for package-based rename migration

- Why: The rename must reach existing Sparkle-enabled Insomnia users through the updater, including users who do not update immediately.
- How: Approved the design in [spec.md](./spec.md) to keep the legacy Insomnia appcast alive for 3 months, freeze it on a single migration item, and deliver the rename via a Sparkle package update into Adrenaline.
- Decision: Prefer a temporary compatibility bridge over permanent dual-feed publishing or a brittle direct bundle rename update.

### 2026-05-03 13:36 — Implementation plan written

- Why: Spec approved, need concrete executable tasks.
- How: Wrote [plan.md](./plan.md) with 6 tasks: fix adrenaline appcast metadata, create postinstall script, create pkg build script, create legacy insomnia repo with gh-pages, build/publish migration release, end-to-end verification.
- Decision: Discovered old `tonioriol.github.io/insomnia/appcast.xml` returns 404 because the repo was renamed — need to create a new `tonioriol/insomnia` repo to restore that URL.
