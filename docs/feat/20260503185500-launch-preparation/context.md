---
title: "Pre-launch preparation and resource profiling"
status: done
repos: [adrenaline]
tags: [launch, performance]
created: 2026-05-03
---

# Pre-launch preparation and resource profiling

## TASK

**Goal:** Profile Adrenaline's resource footprint and prepare the launch strategy before public announcement.

**Done when:** Resource numbers documented, launch plan with specific channels/timing/copy written down.

## SPEC

No separate spec needed — this is a profiling + planning task.

## FILES

- Resources/Adrenaline/Info.plist
- README.md

## PLAN

No separate plan needed — single-session work.

**Cursor:** Done

**Status:** done

## LOG

### 2026-05-03 17:56 — Resource profiling baseline

- Why: Need concrete numbers for launch posts and to verify the app isn't leaking resources.
- How: Ran `ps`, `top`, and `pmset -g assertions` monitoring while the app was idle for 15 minutes.
- Results:
  - **Adrenaline app:** 0.0% CPU, 24.4 MB RSS at idle
  - **Privileged helper:** 0.0% CPU, 4 MB RSS at idle
  - **Total footprint:** ~25 MB real memory, 0% CPU

### 2026-05-03 18:31 — Stress test during lid events and feature toggling

- Why: Verify no CPU runaway or memory leaks during real usage scenarios.
- How: Ran 3-minute continuous monitor (2s samples) while user toggled: awake on/off, lid close/open, lid-close prevention enable/disable, display sleep toggle.
- Results:
  - **Idle baseline:** 0.0% CPU, 26.8 MB RSS
  - **During lid events:** assertions spiked 8→22→27→9 (IOKit power assertion changes), CPU spiked to 14.9% for one 2s sample and 3.3% for another — both transient sub-second event handlers
  - **Peak RSS:** 40.7 MB during rapid toggling
  - **Recovery:** RSS returns to ~27 MB within 20 seconds, CPU returns to 0.0% immediately
  - **Verdict:** No memory leaks, no sustained CPU usage, assertion management correct

### 2026-05-03 17:55 — Launch strategy defined

- Why: App is ready for public launch, need a concrete plan for where/when/what to post.
- How: Analyzed the app's positioning (native Swift menu bar utility, open source AGPL-3.0, unique lid-close feature) against available channels.
- Launch plan:

**Preparation (before posting):**
1. Add screenshot/GIF to top of README.md showing menu bar icon and right-click menu
2. Add GitHub topics: `macos`, `swift`, `menu-bar`, `sleep`, `caffeine`, `clamshell-mode`
3. Submit to homebrew/homebrew-cask for `brew install --cask adrenaline` without tap

**Launch day (Monday or Tuesday, 14:00-16:00 Madrid / 8-10 AM ET):**
4. Post Show HN — title: "Show HN: Adrenaline – Keep your Mac awake from the menu bar, even with the lid closed"
5. Post r/macapps — "Adrenaline — free, open-source menu bar app to keep your Mac awake (even with the lid closed)"
6. Post r/mac — "I made a free app that keeps your Mac awake with the lid closed — no external display needed"
7. Post X/Bluesky/Mastodon thread with screenshot

**Follow-up (same week):**
8. Submit to AlternativeTo as alternative to Caffeine, Amphetamine, KeepingYouAwake
9. Submit to MacUpdate

**Key differentiator:** "keeps your Mac awake with the lid closed — no external display needed"

**Show HN post body:**
```
I built a macOS menu bar app that prevents system sleep — including with the lid closed (clamshell mode without an external display).

Left-click toggles awake on/off. Right-click for options: prevent display sleep, prevent sleep with lid closed, lid event sounds, launch at login.

The lid-close feature uses a privileged helper with IOKit to override Apple's default "close lid = sleep" behavior. Useful for running long tasks, servers, or downloads while the laptop is closed.

Native Swift, no Electron, no runtime. ~25MB total memory, 0% CPU at idle. Open source (AGPL-3.0).

Install: brew install --cask tonioriol/adrenaline/adrenaline
Source: https://github.com/tonioriol/adrenaline
```
