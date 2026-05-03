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

Pending — design not approved yet.

## FILES

- Resources/Adrenaline/Info.plist
- Sources/Adrenaline/SparkleUpdaterController.swift
- .github/workflows/release.yml
- README.md
- Casks/adrenaline.rb

## PLAN

**Plan:** No plan written yet.

**Cursor:** Brainstorming — define rename-via-update migration design

**Status:** in_progress

## LOG

### 2026-05-03 09:29 — Task opened for updater migration design

- Why: The rename from Insomnia to Adrenaline was shipped as a product/repository rename, but existing installed Insomnia builds still check the old Sparkle feed and therefore cannot discover the new Adrenaline line automatically.
- How: Created a dedicated task ledger to design the Sparkle/appcast/release migration path before making more updater changes.
- Decision: Treat this as a migration design problem, not a cosmetic rename follow-up.
